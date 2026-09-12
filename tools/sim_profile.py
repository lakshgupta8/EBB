"""Writes a sim profile (the bots' save file) in a chosen state, for screenshots and checks.
    python tools/sim_profile.py fresh|village|epilogue-break|epilogue-walk|keep
The file is %APPDATA%/Godot/app_userdata/EBB/sim_save.json; the real profile is untouched.
"""
import json
import os
import sys

PATH = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "EBB", "sim_save.json")

BASE = {"version": 2, "pearls": 180, "runs": 14, "wins": 3, "best_depth": 42, "total_kills": 900,
        "ledger": {"constitution": 2, "kinder_tide": 1}, "flags": {}, "weapon": "bell",
        "weapons": ["gaff", "net", "harpoon", "lantern", "bell", "line"], "blessed_family": "salt",
        "charted_room": 2, "echoes": 0, "codex": {}, "endings": [], "suspended": {}, "shards": 9,
        "aspects": {}, "aspects_owned": [], "tide_tier": 0, "tide_unlocked": 3}


def village():
    d = dict(BASE)
    for e in ["bram", "pell", "wren", "cartographer", "choir", "aldous", "maren"]:
        d["flags"]["echo_" + e] = True
    for b in ["wreck", "chainmother", "bell", "ebb"]:
        d["flags"]["boss_%s_broken" % b] = True
    d["flags"]["ebb_broken"] = True
    d["echoes"] = 7
    d["glass"] = 3
    d["shells"] = 2
    d["journals"] = [1, 2, 3, 4, 5]
    d["affinity"] = {"bram": 1, "nessa": 2}
    d["stats"] = {"kills": 900, "vaults": 4, "challenges": 3, "dives": 5, "wet_rooms": 6, "gifts": 3, "glass_found": 5}
    d["kills_by"] = {"shellback": 40, "gull": 25, "wrack_crab": 12}
    d["fen_quest"] = 3
    d["fish"] = ["eel", "cod"]
    d["keel"] = "iron"
    d["keels_owned"] = ["iron"]
    d["contracts_done"] = ["gulls", "wreck", "hold"]
    d["log"] = ["first_night", "ten_kills", "third_room", "wreck", "bram", "chainmother", "bell", "first_win", "three_wins",
                "kills_100", "kills_500", "vault_1", "challenge_1", "dive_1", "wet_5", "echoes_5", "journals_3"]
    d["cosmetics_owned"] = ["warm", "cold", "green", "keeper", "fisher"]
    d["cosmetics"] = {"lantern": "cold", "coat": "fisher"}
    return d


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "village"
    if mode == "fresh":
        d = {"version": 2}
    else:
        d = village()
        if mode == "epilogue-break":
            d["endings"] = ["break"]
            d["epilogue"] = "break"
        elif mode == "epilogue-walk":
            d["endings"] = ["keep", "break", "walk"]
            d["epilogue"] = "walk"
        elif mode == "keep":
            d["endings"] = ["keep"]
            d["epilogue"] = "keep"
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(d, f, indent="\t")
    print("wrote", mode, "->", PATH)


if __name__ == "__main__":
    main()
