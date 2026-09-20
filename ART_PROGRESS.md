# EBB — Art Redesign Progress

Roadmap: `ART_ROADMAP.md` (the user's brief, verbatim, 23 stages). Spec: `STYLE.md`. Audit: `ART_ASSET_AUDIT.md`.

Rule: one stage per approval. The next stage starts only on an explicit "Proceed to Stage X."

## Current stage

**Stage 10 — Tile and water system: COMPLETE, awaiting review.**
Next stage on approval: **Stage 11 — Lighting (near-neutral night tint, lantern retune, two-zone light texture, cold sources, no bloom).**

## Stage log

| Stage | Status | Output |
|---|---|---|
| 01 Audit | done 2026-09-12 | `ART_ASSET_AUDIT.md` |
| 02 Style bible | done 2026-09-12 | `STYLE.md` v1.0 |
| 03 Colour system | done 2026-09-19 | `tools/palette.py`, `src/core/palette.gd`, `assets/reference/palette.png`, STYLE.md v1.1 |
| 04 Pixel rules | done 2026-09-19 | `assets/reference/pixel_rules.png`, STYLE.md v1.2 |
| 05 Visual anchors | done 2026-09-19 | `assets/reference/anchors/`, STYLE.md v1.3 |
| 06 Characters | done 2026-09-19 | Tam 18 frames + coats, Maren, Bram; STYLE.md v1.4 |
| 07 Enemies | done 2026-09-19 | 11 enemy sheets + 3 elite costumes; STYLE.md v1.5 |
| 08 Bosses | done 2026-09-19 | Wreck 72x48, Bell 48x72, Ebb 72x72 at scale 1; STYLE.md v1.6 |
| 09 Environments | done 2026-09-20 | 45-cell tileset, 3 decor sets, props, doors, signboards, lighthouse from `tools/gen_tiles.py`; wall facing, shade layer, hub theme; STYLE.md v1.7 |
| 10 Tile and water | done 2026-09-20 | `tools/gen_water.py`: water atlas, foam autotile, edges, splash/ripple/bubble/wet edge, six door arches; room.gd overlay layers, water shader, entity wading; STYLE.md v1.8 |
| 11-23 | not started | |

## Completed assets

Shipped (`assets/sprites/`, wired into the game):
- Tam, coats, Maren, Bram (06). Eleven enemies, three elite costumes (07). Three bosses at native size (08). Tileset, decor, props, signboards, lighthouse (09).
- `water.png` 256x96 (Stage 10): row 0 shallow A/B x3 frames, deep ring A/B x2, deep x2, abyss ring x2, abyss x2; rows 1-3 foam (16 cases by dry neighbours, one row per frame); row 4 wet band (16 cases); row 5 tide line (16 cases).
- `fx_splash.png` 3x16x16, `fx_ripple.png` 3x16x8, `fx_bubble.png` 2x4x4, `fx_wet.png` 16x2.
- `door.png` 6x32x32: shut, open, water-closed, flooded, wet shortcut shut, wet shortcut open. (`gen_tiles.py` no longer writes door.png; `gen_water.py` owns it.)
- Engine: `Tiles.water_tileset()`; `room.gd` builds Edge, Water and Foam layers at z 0 under the content, picks every cell from the height map (`Room.Body`, `_foam_case`, wet band, tide line, BFS distance for the deep dither rings), animates at 3 fps (deep at half), spawns bubbles; `src/world/water.gdshader` adds light glints; `door.gd` picks its arch from wet/open/flooded (`Door.frame_for`, polled each physics frame); `player.gd` and `enemy_base.gd` show a wet edge, splash, ripples and a fainter shadow while wading; `fx.gd` has `splash`, `ripple`, `bubble` and caches SpriteFrames; `Settings.WATER_TINTS` lost their alpha; `run.gd` takes `--tide=N`.
- Tests: `tests/test_water.gd` (foam faces dry ground, tide line on dry low ground, deep dither rings, door frames). 73 tests pass.

Reference: `assets/reference/anchors/water_sheet.png` (the atlas over sand; the bodies over sand, cobble, basalt, hub sand and deck; three mock pools at tide 0 / 0.5 / 1.5 / 2.5 drawn by the same rules as room.gd; the six arches; the effects).

## Remaining assets (from the audit)

- Harbour tiles (26-31) and `decor4.png`, the six post-brief enemies and Chainmother, eight more elite costumes: Stage 19.
- Characters: Orla, Fen, Wren, Cartographer, Merchant, Nessa, Idris, Aldous, Pell, Choir at 24 px; portraits; the vault prop; the dock.
- Weapons, FX (non-water), UI, type, title: as before.
- Old water cells in `tiles.png` (4-6, 12-13) are now unused by the room; they stay so the enum does not move.

## Known inconsistencies (open)

- Night tint is still the placeholder blue multiply. Every biome reads darker than target; the Hall is near-black; deep water at high tide is a black rectangle with ripples. Stage 11.
- Foam never touches a wall (walls are not shore), so a building standing in water has no foam at its foot, only its shade band. A decision, not a bug; reverse in `room.gd` `_refresh_water` if the user wants foam at walls.
- The dither rings follow 4-neighbour distance, so a pool's deep boundary steps in diamonds, not curves.
- Decor placement is random within open cells, not rule-based. Stage 12.
- Door tiles under the frame are symmetric and do not rotate with the frame; hidden in play.
- Boss phase tints, drop shadows, death squash, Still Citizen double-darkening, mixed hub scale, colour literals, audit section 16: as before.

## Decisions locked in STYLE.md v1.8 (reverse by editing STYLE.md, not by ignoring it)

- Water is a runtime overlay from `water.png`; floors never carry flood state.
- Entities draw above the water and carry the wading on the body (wet edge, splash, ripple, faint shadow).
- Foam only on the water tile's edges that touch dry floor; the wet band on the dry side; the tide line dashed round dry low ground.
- Deep water dithers two tiles in from anything shallow and goes to Abyss five tiles in.
- Six door arches, chosen by wet / open / flooded.
- Everything from v1.0-1.7.

## Decisions still pending the user

- Tide line strength: dashed full Salt white now; the alternative is 160 alpha or 3-on-3-off.
- Foam at walls (see above).
- Whether the Streets cobbles read as a street or as a brick grid at 1x; whether the Hall floor is too featureless once the tint is fixed.
- Ebb ghost-or-figure; Wreck deck; Bell Ringer bear-or-person; Wrack Crab roundness; Violet light.

## Visual QA findings

- Sheet, first pass: the water-closed arch drew its grate as vertical stripes (fixed: the shut grate composited under Sea at 55 % with a foam line); the wet passage's two glints read as eyes (fixed: one Shallow surface line); the mock pools ran off the sheet (fixed: 2x, four tides).
- In game (hub, Flats dive room at tide 0.5 / 1.5 / 2.5, Streets 1.4, Hall 1.4): foam rims every dry island and the hub shore, the wet band darkens the sand edge, the dock pile stands in a foam ring, Tam and the anchors carry the 2 px wet edge, the swimmer sits in a ripple ring, doors show the flooded arch when the tide reaches the doorway, glints show in the lantern and altar pools. First glint pattern repeated every 9 px in every row (fixed: 7-12 px per row).
- Tooling: a `light()` shader using `LIGHT_VERTEX` hung Godot at startup; the shader anchors its pattern to a `world_pos` varying instead. A PowerShell screenshot helper with a parameter named `$args` launches the game with no flags (PowerShell reserves `$args`), which looked like six renderer hangs in a row; the helper's parameter is `$flags`.

## Next visual task

On approval: Stage 11. Switch the `CanvasModulate` to `Palette.NIGHT_TINT_RUN` / `NIGHT_TINT_HUB`, retune Tam's lantern (energy ~0.7, Warm yellow toward Pale cream, scale ~3.2), replace `glow.png` with the two-zone falloff and add the 24 px candle texture, bring every cold source to Sea pale at 0.3-0.5 energy, cap flashes at 0.4 alpha, and re-shoot every biome, the hub and a boss at three tides against the `palette.png` night-tint check.
