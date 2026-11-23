"""The blind test for audio Stage 09: a page that plays every enemy's tell in a random order and
asks which enemy it is, then shows the score; and a sheet of every combat sound by enemy (its tells,
its hit layer, its death) and by weapon (all six). Local only, in assets/reference/audio/combat/.

    python tools/gen_tell_quiz.py
"""
import json
import os
import re
import shutil

WEAPONS = {  # each weapon's set, as its code plays it
    "the gaff": ["gaff_swing", "gaff_heavy", "gaff_hit", "gaff_hook"],
    "the net knife": ["knife_stab", "knife_hit", "knife_cut", "knife_net"],
    "the harpoon gun": ["harpoon_fire", "harpoon_hit", "harpoon_reload", "harpoon_tether", "harpoon_drag"],
    "the keeper's bell": ["kbell_swing", "kbell_slam", "kbell_hit", "kbell_toll"],
    "the line and sinker": ["line_crack", "line_hit", "line_throw", "line_sink"],
    "the storm lantern": ["lantern_arc", "lantern_hit", "lantern_throw", "lantern_beacon"],
}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
OUT = os.path.join(ROOT, "assets", "reference", "audio", "combat")


def voices():
    """Enemy.VOICES, read out of enemy_base.gd, each with the place its "# the ..." heading names."""
    src = open(os.path.join(ROOT, "src", "enemies", "enemy_base.gd"), encoding="utf-8").read()
    body = src[src.index("const VOICES"):]
    body = body[:body.index("\n}")]
    out, place = {}, ""
    for line in body.splitlines():
        h = re.match(r"^\t# (the \w+)", line)
        if h:
            place = h.group(1)
        m = re.match(r'^\t"(\w+)": \{"tells": \{(.*?)\}, "material": "(\w+)"\}', line)
        if m:
            tells = dict(re.findall(r'&"(\w+)": "(\w+)"', m.group(2)))
            out[m.group(1)] = {"tells": tells, "material": m.group(3), "place": place}
    return out


def first(name):
    for f in (name + ".wav", name + "_0.wav"):
        if os.path.exists(os.path.join(AUDIO, f)):
            return f
    return None


def main():
    os.makedirs(OUT, exist_ok=True)
    v = voices()
    clips = {}
    for enemy, d in v.items():
        for state, tell in d["tells"].items():
            f = first(tell)
            if f:
                shutil.copy(os.path.join(AUDIO, f), os.path.join(OUT, f))
                clips[f] = {"enemy": enemy, "state": state, "place": d["place"]}
        for kind in ("hit", "die"):
            f = first(f"{kind}_{d['material']}")
            if f:
                shutil.copy(os.path.join(AUDIO, f), os.path.join(OUT, f))
    weapons = {}
    for w, names in WEAPONS.items():
        weapons[w] = [f for f in map(first, names) if f]
        for f in weapons[w]:
            shutil.copy(os.path.join(AUDIO, f), os.path.join(OUT, f))
    places = list(dict.fromkeys(d["place"] for d in v.values()))
    css = ("body{font:15px system-ui;background:#10141c;color:#d8dde6;margin:24px;max-width:860px}"
           "button,select{font:inherit;padding:6px 10px;margin:4px;background:#1c2533;color:#d8dde6;border:1px solid #33415a;border-radius:4px}"
           "td{padding:6px 10px;border-bottom:1px solid #263040}h1,h2{color:#7fd1c7}.ok{color:#8fd18f}.no{color:#f0a868}audio{height:28px}")
    page = f"""<!doctype html><meta charset=utf-8><title>EBB: name the tell</title><style>{css}</style>
<h1>Name the tell</h1>
<p>Audio Stage 09's gate. Each sound below is an enemy winding up. Play it, pick who it is, then check.
One place at a time, since those are the enemies to tell apart. Headphones, one volume. The order
is shuffled each time.</p>
<div id=places></div><div id=quiz></div><button onclick="score()">Check</button> <span id=result></span>
<h2>Every combat sound</h2><table id=sheet></table>
<script>
const clips = {json.dumps(clips)};
const places = {json.dumps(places)};
const voices = {json.dumps(v)};
const weapons = {json.dumps(weapons)};
let keys = [];
const quiz = document.getElementById('quiz');
function start(place) {{
  keys = Object.keys(clips).filter(k => clips[k].place === place).sort(() => Math.random() - 0.5);
  const enemies = Object.keys(voices).filter(e => voices[e].place === place).sort();
  quiz.innerHTML = `<h2>${{place}}</h2>`;
  document.getElementById('result').textContent = '';
  keys.forEach((k, i) => {{
    const row = document.createElement('div');
    row.innerHTML = `<b>${{i + 1}}.</b> <audio controls preload=none src="${{k}}"></audio>
      <select id="q${{i}}"><option value="">who?</option>${{enemies.map(e => `<option>${{e}}</option>`).join('')}}</select>
      <span id="a${{i}}"></span>`;
    quiz.appendChild(row);
  }});
}}
document.getElementById('places').innerHTML = places.map(p => `<button onclick="start('${{p}}')">${{p}}</button>`).join('');
start(places[0]);
function score() {{
  let right = 0;
  keys.forEach((k, i) => {{
    const pick = document.getElementById('q' + i).value, truth = clips[k];
    const ok = pick === truth.enemy;
    right += ok ? 1 : 0;
    document.getElementById('a' + i).innerHTML = ok ? '<span class=ok>yes</span>'
      : `<span class=no>${{truth.enemy}} (${{truth.state}})</span>`;
  }});
  document.getElementById('result').textContent = `${{right}} of ${{keys.length}} named by ear`;
}}
const sheet = document.getElementById('sheet');
for (const [e, d] of Object.entries(voices)) {{
  const cells = Object.values(d.tells).map(t => `${{t}} <audio controls preload=none src="${{t}}_0.wav"></audio>`).join('<br>');
  sheet.innerHTML += `<tr><td><b>${{e}}</b><br>${{d.place}}, ${{d.material}}</td><td>${{cells}}</td>
    <td>hit <audio controls preload=none src="hit_${{d.material}}_0.wav"></audio><br>
    death <audio controls preload=none src="die_${{d.material}}_0.wav"></audio></td></tr>`;
}}
for (const [w, files] of Object.entries(weapons))
  sheet.innerHTML += `<tr><td><b>${{w}}</b></td><td>` + files
    .map(g => `${{g.replace('.wav', '')}} <audio controls preload=none src="${{g}}"></audio>`).join('<br>') + `</td><td></td></tr>`;
</script>"""
    open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(page)
    print(f"quiz: {len(clips)} tells from {len(v)} enemies in {len(places)} places -> {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
