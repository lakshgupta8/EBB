"""The audio audit (audio Stage 01): measures every clip in assets/audio and says where each one
falls against the targets in STYLE.md section 23.

    python tools/audio_audit.py                       measure, print the summary
    python tools/audio_audit.py --log a.json b.json   also how often a bot night asked for each
                                                      clip (tests/sim_run.gd --audio-log=PATH)

Writes assets/reference/audio/audit.csv and listening.html (local only, like every review sheet):
the sheet plays each clip in a browser beside its numbers.

Loudness is ITU-R BS.1770-4 (K-weighted, gated), measured as the game plays it: a mono clip goes
out to both speakers, so it counts as dual mono (+3 dB over one channel). An effect too short to
gate is measured by its loudest 400 ms (momentary max).
"""
import argparse
import csv
import html
import json
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter, resample_poly

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
OUT = os.path.join(ROOT, "assets", "reference", "audio")

# The targets (STYLE.md 23.4). Effects by role, measured by their loudest 400 ms; music and beds
# integrated. Every clip's true peak at or under -1 dBTP.
TARGETS = {
    "music": ("integrated", -18.0, 1.5),
    "stinger": ("momentary", -14.0, 2.0),
    "ambience": ("integrated", -26.0, 2.0),
    "tell": ("momentary", -13.0, 2.0),
    "combat": ("momentary", -15.0, 2.0),
    "layer": ("momentary", -18.0, 2.0),   # a material's body under a weapon's hit (audio Stage 09)
    "world": ("momentary", -18.0, 2.0),
    "interface": ("momentary", -20.0, 2.0),
}
PEAK_MAX = -1.0

# Which role each effect plays (by base name); anything else is "world".
ROLES = {
    "tell": ["roar", "bell", "chain", "wave", "riptide", "wake", "flare", "ebb", "hymn", "net", "harpoon"],
    "combat": ["hit", "crit", "swing", "stab", "heavy", "hook", "bite", "hurt", "death", "dash", "reload", "lantern"],
    "interface": ["ui", "buy", "page", "gift", "pickup", "pearl"],
}


def role_of(name):
    if name.startswith("music_"):
        return "music"
    if name.startswith("stinger_") or name == "clear":
        return "stinger"
    if name.startswith("amb") :
        return "ambience"
    if name.startswith("tell_"):
        return "tell"
    if re.match(r"hit_[a-z]+_\d+$", name):
        return "layer"
    if name.startswith(("die_", "gaff_", "knife_", "harpoon_", "kbell_", "line_", "lantern_")):
        return "combat"
    base = re.sub(r"_\d+$", "", name)
    for r, names in ROLES.items():
        if base in names:
            return r
    return "world"


def read(path):
    """Samples as float frames x channels, and the rate. Ogg goes through ffmpeg."""
    if path.endswith(".wav"):
        sr, x = wavfile.read(path)
        fmt = str(x.dtype)
    else:
        tmp = tempfile.mktemp(suffix=".wav")
        subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", path, "-c:a", "pcm_s16le", tmp], check=True)
        sr, x = wavfile.read(tmp)
        os.remove(tmp)
        fmt = "ogg"
    if x.dtype == np.int16:
        x = x.astype(np.float64) / 32768.0
    elif x.dtype == np.int32:
        x = x.astype(np.float64) / 2147483648.0
    elif x.dtype == np.uint8:
        x = (x.astype(np.float64) - 128.0) / 128.0
    else:
        x = x.astype(np.float64)
    if x.ndim == 1:
        x = x[:, None]
    return sr, x, fmt


def _biquads(sr):
    """The two K-weighting stages for any rate (the BS.1770 analogue prototypes)."""
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    a = 10 ** (g / 40.0)
    w = 2 * np.pi * f0 / sr
    al = np.sin(w) / (2 * q)
    c = np.cos(w)
    shelf = (
        [a * ((a + 1) + (a - 1) * c + 2 * np.sqrt(a) * al), -2 * a * ((a - 1) + (a + 1) * c),
         a * ((a + 1) + (a - 1) * c - 2 * np.sqrt(a) * al)],
        [(a + 1) - (a - 1) * c + 2 * np.sqrt(a) * al, 2 * ((a - 1) - (a + 1) * c),
         (a + 1) - (a - 1) * c - 2 * np.sqrt(a) * al],
    )
    f0, q = 38.13547087602444, 0.5003270373238773
    w = 2 * np.pi * f0 / sr
    al = np.sin(w) / (2 * q)
    c = np.cos(w)
    high = ([(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + al, -2 * c, 1 - al])
    return shelf, high


def loudness(sr, x):
    """(integrated LUFS or None, momentary max LUFS, short-term max LUFS)."""
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)  # dual mono: what the speakers play
    (sb, sa), (hb, ha) = _biquads(sr)
    y = lfilter(hb, ha, lfilter(sb, sa, x, axis=0), axis=0)
    def blocks(sec, hop):
        n, h = int(sec * sr), int(hop * sr)
        yy = y if len(y) >= n else np.vstack([y, np.zeros((n - len(y), y.shape[1]))])
        out = []
        for s in range(0, len(yy) - n + 1, h):
            out.append(np.sum(np.mean(yy[s:s + n] ** 2, axis=0)))
        return np.array(out)
    def lufs(z):
        return -0.691 + 10 * np.log10(np.maximum(z, 1e-12))
    m = blocks(0.4, 0.1)
    st = blocks(3.0, 0.1) if len(y) >= 3 * sr else m
    integrated = None
    if len(y) >= sr:
        z = blocks(0.4, 0.1)
        z = z[lufs(z) > -70]
        if len(z):
            z = z[lufs(z) > lufs(np.mean(z)) - 10]
            integrated = float(lufs(np.mean(z)))
    return integrated, float(lufs(m.max())), float(lufs(st.max()))


def spectrum(sr, x):
    """(centroid Hz, the frequency under which 99% of the energy lies, % of energy above 4 kHz)."""
    mono = x.mean(axis=1)
    n = 1 << int(np.ceil(np.log2(max(len(mono), 2048))))
    p = np.abs(np.fft.rfft(mono * np.hanning(len(mono)), n)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / sr)
    tot = p.sum() + 1e-30
    cum = np.cumsum(p) / tot
    return float((f * p).sum() / tot), float(f[np.searchsorted(cum, 0.99)]), float(100 * p[f > 4000].sum() / tot)


def seam(sr, x):
    """How hard a loop's end jumps back to its start, against a typical step (1 = seamless)."""
    m = x.mean(axis=1)
    typical = np.median(np.abs(np.diff(m))) + 1e-9
    return float(abs(m[0] - m[-1]) / typical)


def used_in_code():
    """Every quoted string in the game's code and data: a clip nobody names is suspect."""
    text = []
    for d in ("src", "data"):
        for dp, _, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                if f.endswith((".gd", ".tscn", ".json", ".tres")):
                    text.append(open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read())
    return "\n".join(text)


def usage(name, code):
    base = re.sub(r"_\d+$", "", name)
    if f'"{name}"' in code or f'"{base}"' in code:
        return "named"
    prefix = name.split("_")[0] + "_"
    if f'"{prefix}' in code:
        return "built"  # e.g. "amb_" + biome, "gull_%d"
    return "unused?"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", nargs="*", default=[], help="bot nights' --audio-log files")
    args = ap.parse_args()

    asked, seconds = {}, 0.0
    for p in args.log:
        d = json.load(open(p, encoding="utf-8"))
        seconds += float(d["seconds"])
        for k, v in d["asked"].items():
            asked[k] = asked.get(k, 0) + int(v)
    nights = max(len(args.log), 1)

    code = used_in_code()
    rows = []
    for f in sorted(os.listdir(AUDIO)):
        if not f.endswith((".wav", ".ogg")):
            continue
        name = os.path.splitext(f)[0]
        sr, x, fmt = read(os.path.join(AUDIO, f))
        integ, mom, st = loudness(sr, x)
        cen, top, air = spectrum(sr, x)
        peak = 20 * np.log10(np.abs(x).max() + 1e-12)
        tp = 20 * np.log10(np.abs(resample_poly(x, 4, 1, axis=0)).max() + 1e-12)
        role = role_of(name)
        kind, target, tol = TARGETS[role]
        measured = integ if kind == "integrated" else mom
        if kind == "momentary" and len(x) / sr < 0.4:
            # Shorter than the 400 ms window: a strike is judged by its peak (as loud as it may be).
            kind, target, tol = "peak", -1.5, 1.5
            measured = 20 * np.log10(np.abs(resample_poly(x, 4, 1, axis=0)).max() + 1e-12)
        off = None if measured is None else measured - target
        base = re.sub(r"_\d+$", "", name)
        loops = role in ("music", "ambience")
        rows.append({
            "clip": name, "role": role, "format": fmt, "rate": sr, "channels": x.shape[1],
            "seconds": round(len(x) / sr, 2),
            "integrated_lufs": None if integ is None else round(integ, 1),
            "momentary_max": round(mom, 1), "short_term_max": round(st, 1),
            "peak_dbfs": round(peak, 1), "true_peak_dbtp": round(tp, 1),
            "target": f"{target:g} {kind}", "off_lu": None if off is None else round(off, 1),
            "centroid_hz": round(cen), "top_hz": round(top), "air_pct": round(air, 1),
            "seam": round(seam(sr, x), 1) if loops else None,
            "code": usage(name, code),
            "per_night": round(asked.get(base, asked.get(name, 0)) / nights, 1) if args.log else None,
        })
        r = rows[-1]
        r["flags"] = " ".join(filter(None, [
            "loud" if off is not None and off > tol else "",
            "quiet" if off is not None and off < -tol else "",
            "over-peak" if tp > PEAK_MAX else "",
            "dull" if top < 6000 and role != "ambience" else "",
            "mono" if x.shape[1] == 1 and role in ("music", "ambience") else "",
            "low-rate" if sr < 44100 else "",
            "seam" if loops and r["seam"] > 8 else "",
            "unused?" if r["code"] == "unused?" else "",
        ]))

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "audit.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    write_sheet(rows, seconds / nights if args.log else None, asked)

    # The summary.
    by_role = {}
    for r in rows:
        by_role.setdefault(r["role"], []).append(r)
    total = sum(os.path.getsize(os.path.join(AUDIO, f)) for f in os.listdir(AUDIO) if f.endswith((".wav", ".ogg")))
    print(f"{len(rows)} clips, {total / 1e6:.1f} MB; rates {sorted({r['rate'] for r in rows})}, "
          f"channels {sorted({r['channels'] for r in rows})}")
    for role, rs in by_role.items():
        kind, target, tol = TARGETS[role]
        offs = [r["off_lu"] for r in rs if r["off_lu"] is not None]
        print(f"  {role:9s} {len(rs):3d} clips  {sum(r['seconds'] for r in rs):7.1f} s  "
              f"loudness vs {target:g}: {min(offs):+.1f} to {max(offs):+.1f} LU  "
              f"top {min(r['top_hz'] for r in rs)}-{max(r['top_hz'] for r in rs)} Hz  "
              f"in range {sum(abs(o) <= tol for o in offs)}/{len(offs)}")
    flagged = [r for r in rows if r["flags"]]
    print(f"flags: {len(flagged)} clips; " + ", ".join(
        f"{k} {sum(k in r['flags'].split() for r in rows)}"
        for k in ["loud", "quiet", "over-peak", "dull", "mono", "low-rate", "seam", "unused?"]))
    if args.log:
        print(f"a bot night: {seconds / nights / 60:.1f} min, {sum(asked.values()) / nights:.0f} requests")
        top = sorted(asked.items(), key=lambda kv: -kv[1])[:12]
        print("  most asked: " + ", ".join(f"{k} {v / nights:.0f}" for k, v in top))
        missing = sorted(k for k in asked if not any(r["clip"] == k or re.sub(r"_\d+$", "", r["clip"]) == k for r in rows))
        if missing:
            print("  asked for but no clip: " + ", ".join(missing))
    print(f"wrote {os.path.relpath(OUT, ROOT)}\\audit.csv and listening.html")


def write_sheet(rows, night_seconds, asked):
    """A page that plays each clip beside its numbers, grouped by role."""
    css = ("body{font:14px system-ui;background:#10141c;color:#d8dde6;margin:24px}"
           "table{border-collapse:collapse;width:100%}td,th{padding:4px 8px;border-bottom:1px solid #263040;"
           "text-align:left;white-space:nowrap}th{color:#8fa3bf;font-weight:600}"
           "h2{color:#7fd1c7;margin-top:32px}.f{color:#f0a868}audio{height:28px;width:220px}"
           "td.n{color:#9aa4b2}")
    cols = ["seconds", "integrated_lufs", "momentary_max", "true_peak_dbtp", "target", "off_lu", "top_hz",
            "air_pct", "seam", "per_night", "code", "flags"]
    out = [f"<!doctype html><meta charset=utf-8><title>EBB listening sheet</title><style>{css}</style>",
           "<h1>EBB: every clip</h1><p>Audio Stage 01. Listen with headphones at one volume. "
           "Loudness as the game plays it (mono counts twice). Targets: STYLE.md section 23.</p>"]
    if night_seconds:
        out.append(f"<p>Bot night: {night_seconds / 60:.1f} min. <i>per night</i> = how often the night asked for it.</p>")
    order = ["music", "stinger", "ambience", "tell", "combat", "layer", "world", "interface"]
    for role in order:
        rs = [r for r in rows if r["role"] == role]
        if not rs:
            continue
        out.append(f"<h2>{role} ({len(rs)})</h2><table><tr><th>clip</th><th>listen</th>"
                   + "".join(f"<th>{c.replace('_', ' ')}</th>" for c in cols) + "<th>notes</th></tr>")
        for r in rs:
            ext = "wav" if r["format"] != "ogg" else "ogg"
            src = f"../../audio/{r['clip']}.{ext}"
            cells = "".join(
                f"<td class={'f' if c == 'flags' else 'n'}>{html.escape('' if r[c] is None else str(r[c]))}</td>" for c in cols)
            out.append(f"<tr><td>{r['clip']}</td><td><audio controls preload=none src='{src}'></audio></td>{cells}"
                       "<td contenteditable=true></td></tr>")
        out.append("</table>")
    open(os.path.join(OUT, "listening.html"), "w", encoding="utf-8").write("\n".join(out))


if __name__ == "__main__":
    sys.exit(main())
