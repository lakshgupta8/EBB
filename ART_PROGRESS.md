# EBB — Art Redesign Progress

Roadmap: `ART_ROADMAP.md` (the user's brief, verbatim, 23 stages). Spec: `STYLE.md`. Audit: `ART_ASSET_AUDIT.md`.

Rule: one stage per approval. The next stage starts only on an explicit "Proceed to Stage X."

## Current stage

**Stage 21 — Biome keyframe pass: COMPLETE, awaiting review.** (Stages 01-20 are committed; Stage 21 is committed as its own commit.)
Next stage on approval: **Stage 22 (the full consistency audit).**

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
| 11 Lighting | done 2026-09-20 | near-neutral night tint, `tools/gen_light.py` textures, every light retuned to palette colours, haze per place, flash cap, hub floor one step down, hashed floor variation; STYLE.md v1.9 |
| 12 Parallax and depth | done 2026-09-20 | `tools/gen_scenery.py`: void tiles, 14 far-scenery silhouettes, 9 foreground silhouettes; `Scenery` and `DecorRules` placement; room `Beyond` and `Foreground` layers with a 3 % shift; decor by rule; STYLE.md v1.10 |
| 13 Animation | done 2026-09-20, amended on review | every enemy sheet 16 frames (idle 4, walk 4, windup 2, attack 2, hurt 1, death 3), bosses 18 (plus phase and intro), gull 12; `Enemy.anims` layout binding, `hold_frame`, drawn deaths played by the body left behind; Tam's drawn death plays; STYLE.md v1.11 |
| 14 Weapons | done 2026-09-20 | `tools/gen_weapons.py`: the six held weapons and seven thrown objects as one fisher's kit; held sprites mirrored past the vertical; net never turned or scaled; beacon a placed lantern; STYLE.md v1.12 |
| 15 VFX | done 2026-09-20 | `tools/gen_fx.py`: arc (two colourways), stab, spark, crack, rings at 16/32/96, LIT, STUN, BLEED; `FX` plays everything at 1x, snaps burst and ring colours to the palette, caps bursts; shore spray and drips in `Room`; lantern motes; palette tethers, hit flash, pickup bursts, phase tints; STYLE.md v1.13 |
| 16 UI | done 2026-09-20 | `tools/gen_ui.py`: the kit (iron panel with rivets, paper inset, row states, ledger tabs, triangle cursor), the HUD instruments (health frame, dash lozenges, bronze special, lantern, tide staff, rope-bound boss bar), pickups and currency icons, five family icons at 7 and 15 px, the cursor; `UI` and `hud.gd` rebuilt on it; four text roles, danger as a tag; every menu swept; STYLE.md v1.14 |
| 17 Typography | done 2026-09-20 | the 5x7 font evaluated and **replaced** by two faces from `tools/gen_font.py`: Ledger (8 px, proportional, true descenders, tabular digits) and Plate (16 px slab-serif capitals; 32 for the boss and won banners); `UI` picks the face, size and shadow; the announcer, HUD, room label, hub place name and title tag moved onto them; the whisper face; STYLE.md v1.15 |
| 18 Logo and title | done 2026-09-21 (after 19, by request) | `tools/gen_logo.py`: `logo.png` 108x58 at 1x, slab capitals grown from Plate in the Bone ramp, the lighthouse at their left, a high-water line, foam and a reflection; the title's 2x scale gone; STYLE.md v1.17 |
| 19 Asset library | done 2026-09-21 | category by category against STYLE.md: the village at 24 px with portraits (`tools/gen_people.py`); the six post-brief enemies on the 16-frame layout, the small swarm, the Chainmother native at 48x48, the Shade's bolt, the wax pool, the wisp's shot, the anchor (`tools/gen_enemies_b.py`); eight more elite costumes, every elite and boss at scale 1 (`tools/gen_enemies.py`); the Harbour's tiles, decor, dock, vault and the lighthouse beam (`tools/gen_harbour.py`); STYLE.md v1.16 |
| 20 Composition pass | done 2026-09-22 | eight bot-played gameplay shots read against STYLE.md 20; fixed: water rings as translucent steps (`tools/gen_water.py`), plain Harbour silt (`tools/gen_harbour.py`), HUD plates and the whisper strip over the boss bar (`hud.gd`, `announcer.gd`), the drowned crown rim (`tools/gen_rim.py`, both enemy generators), bosses at 55 % flash and a 0.25 lit light (`enemy_base.gd`); the light knee in `hit_flash.gdshader` for every pale body under stacked lights; STYLE.md v1.18 |
| 21 Keyframes | done 2026-09-22 | `assets/reference/keyframes/` (marrow_rock, flats, streets flooded, hall) at 640x360 from the real game via the run scene's `--keyframe` dev aid and `tools/keyframes.py`; `keyframes_sheet.png`; STYLE.md v1.19 |
| 22-23 | not started | |

## Stage 19, category by category

| # | Category | Checked against | Result |
|---|---|---|---|
| 1 | Player | STYLE.md 7, 17 | Already to spec (Stages 06, 13). Nothing redrawn. |
| 2 | NPCs | 7, 18, 15 (portrait slot) | **Rebuilt.** Ten more people at 24 px on Tam's skeleton, two frames each (`npc_orla/fen/nessa/idris/wren/cartographer/pell/aldous/choir/merchant.png`); `portraits.png`, twelve 16x16 portraits. `Prop` draws every person from a sheet, shows every echo from its own sheet, and `TalkUI` takes the portrait from `portraits.png`; the codex's People tab carries the sprite. The old 16 px strip cells for people are no longer drawn. |
| 3 | Enemies | 7, 8, 17, 18 | **Rebuilt.** Mooring, Deckhand, Barnacle (+ `barnacle_small.png` replacing the 0.7 node scale), Tallow, Choir, Netted on the 16-frame layout, bound with `anims()` (drawn deaths play). Eight more elite costume sheets (gull, lamplighter, bell ringer, swimmer, Shade, anchor, Deep Maw, tidewisp); the 1.25 elite scale no longer has a case to fall back to. |
| 4 | Bosses | 19 | **Rebuilt.** The Chainmother at 48x48 on the boss layout (18 frames); her scene at scale 1, shapes doubled, chain from (0, -12), the cab-window light at (0, -20); `anchor_drop.png` at 24 px. The three brief bosses are Stage 08. |
| 5 | Weapons | 14 | Already to spec (Stage 14). |
| 6 | Projectiles | 14 | `shade_bolt.png` (the Keeper's Shade fires its own bolt in the Night ramp); `wisp_shot.png` in Sea pale; `wax.png` at 40x28 drawn at 1x (the 1.6 scale removed). |
| 7 | Tiles | 10, 8, 20 | **Rebuilt.** Harbour cells 26-31: deck, deck2, hull face, hull top, silt, quay. `gen_tiles.py` keeps them from disk. |
| 8 | Props | 8, 1 | **Rebuilt.** `decor4.png` (eight Harbour pieces), `dock.png`, `prop_vault.png` (24x24 shut and open; `Prop.BIG`); `beam.png` for the lighthouse. |
| 9 | Pickups | 15 | Already to spec (Stage 16). |
| 10 | Effects | 14, 11 | Already to spec (Stage 15); the lighthouse beam added (a turning `PointLight2D` on `beam.png`, the lamp's pool reduced to 2.4). |
| 11 | UI | 15 | Already to spec (Stage 16); the dialog's portrait slot is now filled. |
| 12 | Title assets | 15, 16, 18 | Done in Stage 18: the logo at 1x (`tools/gen_logo.py`). The title's sea, rock, tower and Tam were already on the grid. |

## Stage 20, the composition pass

The shots: `tests/sim_run.tscn` with `--shot=N` (the bot plays and the sim saves the frame), one per situation, kept as `.shots/t20_*.png` (before) and `t20b_*` / `t20c_*` (after): Flats altar room, Flats combat with the harpoon, Harbour, Streets, Streets flooded, Hall, the Bell of Saltmere, and a flooded Flats room at depth 5 with the line.

| Criterion | Read | Result |
|---|---|---|
| Player readability | every shot | Tam is found in under half a second in all eight: the outline, the pool and the warm lantern. No change. |
| Enemy readability | Streets citizen 2.8:1 on cobbles; Hall citizen 1.4:1 on basalt | The drowned humans now carry the Salt white crown (`tools/gen_rim.py`); the Hall stays dark by design. |
| Water readability | flooded Flats, Harbour basin, Streets pools | The shallow-to-deep checkers read as a screen door over a whole pool at 3x: translucent steps now. Foam and the wet band read everywhere. |
| Floor readability | all four biomes | The Harbour silt's tar pools tiled into a lattice across half the screen: plain mud now. Sand, cobble and basalt hold their band. |
| Lighting | all | The pool reads warm on sand, neutral on cobble and basalt (a warm light on a cold floor). Pale bodies under stacked lights clipped to white: fixed by the light knee in `hit_flash.gdshader` (every sprite the lantern can reach), verified on the Bell with Tam's lantern on it. |
| Visual hierarchy | all | Tam > boss > enemies > doors > water edges holds. The Harbour hull top (Iron light) is the brightest surface but sits at the room's edge: judged in play and kept. |
| Clutter | first ten seconds of a room | Hint, toast and whisper can stack; transient, none over the player; left. |
| Contrast | HUD over pale ground | Currency and the staff word had nothing to stand on over Iron light and wet sand: Ink plates now. |
| UI visibility | the Bell | The whisper strip covered the boss name and the bar: the strip rises to y 226 while a bar shows. |
| Effect density | flare, riptide, harpoon, sparks | Under the cap in every shot; the boss hit flash was the one effect that erased its target: 55 % on bosses. |
| Biome identity | all | Flats warm-grey and open, Harbour tar and wood around a basin, Streets cold cobble and pools, Hall black with lit water. Reads. |

## Stage 21, the keyframes

| Place | Frame | What it holds | Requirement check |
|---|---|---|---|
| Marrow Rock | `keyframes/marrow_rock.png` | the twelve people, the beam across the sand, the tide at the dock, Tam's lantern, the hub's info bar | no run HUD and no enemies: the hub has neither; the drowned people stand in for the drowned treatment |
| The Flats | `keyframes/flats.png` | a wet room at tide 0.8: sand, four foam-edged pools and a wet strip, two crabs, two shellbacks, two gulls, the arc, a spark, the cue ring, the HUD | all seven |
| The Drowned Streets | `keyframes/streets.png` | flooded to the doors, a lit lamplighter, citizens, Tam's arc over water, the HUD | all seven; **the flooding keyframe** |
| The Deep Hall | `keyframes/hall.png` | the lit channels, a Tallow on the walk with his wax pool, citizens standing in the water, the HUD | all seven |

Taken with `--keyframe` on the run scene (Tam mid-room, a wave of six, the fight's effects) after the biome card has gone. Rejected on the way: the Flats at tide 1.4 (the whole room under deep water; it flooded but it was not the Flats), and the `--fx` demo's effects (a debug ring, not a fight).

## Completed assets

Shipped (`assets/sprites/`, wired into the game):
- Tam, coats, Maren, Bram (06). Eleven enemies, three elite costumes (07). Three bosses at native size (08). Tileset, decor, props, signboards, lighthouse (09). Water atlas, water effects, six door arches (10). Light textures and haze (11). Void, far scenery, foreground (12). Every enemy and boss sheet at the 13 + 3 layout (13). The fisher's kit (14). The effects (15). The UI kit (16). The two faces (17).
- Stage 19: `npc_orla`, `npc_fen`, `npc_nessa`, `npc_idris`, `npc_wren`, `npc_cartographer`, `npc_pell`, `npc_aldous`, `npc_choir`, `npc_merchant` (2 x 24x24), `portraits` (12 x 16x16); `mooring`, `deckhand`, `barnacle`, `barnacle_small`, `tallow`, `choir`, `netted` (16 x 24x24); `chainmother` (18 x 48x48); `gull_elite`, `lamplighter_elite`, `bell_ringer_elite`, `swimmer_elite`, `keeper_shade_elite`, `anchor_elite`, `deep_maw_elite`, `tidewisp_elite`; `anchor_drop` 24x24, `wax` 40x28, `wisp_shot` 4x4, `shade_bolt` 14x4; `tiles.png` cells 26-31; `decor4` (8 x 16x16); `dock` 48x16; `prop_vault` (2 x 24x24); `beam` 256x48.
- Engine (19): `Prop.NPC_SHEETS` for every person and the merchant, `Prop.PORTRAITS` / `PORTRAIT`, `ECHO_SHEET` for all seven echoes, `_anim` (the drowned at 0.8 fps, the living at 1.5), the merchant no longer bobs (preserved, not floating; alpha 0.92), `Kind.VAULT` in `BIG` with `_big_frame(1)` when opened, the lighthouse `_beam` turning in `_process`; `TalkUI` portraits; `Codex` people sprites; the six enemy scripts on `anims()`; `barnacle.gd` picks `SHEET_SMALL`; `tallow.gd` draws the pool at 1x; `keeper_shade.gd` fires `shade_bolt`; `chainmother.gd` and `.tscn` at 48 px and scale 1; `gen_sprites_m6/m6e/m7.build_all` read the Stage 19 sheets.
- Tests: 96 pass (`tests/test_village.gd` counts twelve portraits).

Reference: `assets/reference/anchors/people_sheet.png`, `enemies_b_sheet.png`, `enemies_sheet.png` (now with eleven elite rows), `harbour_sheet.png`.

## Remaining assets (from the audit)

- The 16 px `props.png` strip still holds cells nothing draws (0 fountain, 3-13 people, 14 vault, 15-19 people); the chest (1, 2) and lantern post (20) are its only live cells. Retire the dead cells when `Prop.FRAMES` is next touched.
- Portraits for Tam (never shown) and the announcer: none needed.

## Known inconsistencies (open)

- The Harbour's hull top (Iron light) was judged in play in Stage 20 and kept: it is the brightest surface but sits at the room's edge as a rim of plating.
- The elite costumes ride the body's bounding box, so on the gull's dive and the anchor's hoist frames they sit a pixel or two off the crown; acceptable at 1x, visible on the sheet.
- The text-size setting scales Ledger to 10 or 12 px (Stage 17 note).
- The three brief bosses are never flagged `is_boss`; the Chainmother is not either (effects key off the drawn frame, which is now 48 px).
- A run cannot be started with a chosen weapon from the command line; a named elite cannot be summoned for a screenshot, so the eight new costumes and the small swarm were judged on the sheets, not in play.
- The ending's lantern light was not caught in a screenshot.
- The Hall floor flatness, foam at walls, dither diamonds, door tiles under the frame, drop shadows, Still Citizen double-darkening, mixed hub scale, colour literals outside lights and effects and menus, audit section 16: as before.

## Decisions locked in STYLE.md v1.16 (reverse by editing STYLE.md, not by ignoring it)

- Every person is a 24 px two-frame sheet; every speaker has a 16x16 portrait; the drowned drip, the living breathe.
- Every enemy is on the 16-frame layout, every elite is a costume sheet, every boss is native at scale 1: there is no node scale left on a character.
- The Harbour is Wood, Tar, Iron and Stone, as 10 says; the lighthouse is a beam, not a pool.
- Everything from v1.0-1.15.

## Decisions still pending the user

- Stretch mode. `canvas_items` renders lights, the haze and the water glints per screen pixel (smooth at 3x); `viewport` would step them to the game pixel like everything else. A Stage 22 audit item under pixel density; it changes how every glow looks, so it is your call.

- The logo's size. It is 30-row capitals (108x58 on a 640x360 screen, 1x). The old one showed 60-row letters (2x). The generator can grow the letters to 40 rows if the title wants more weight; say so and it is one number.
- The Windows icon (`icon.svg`, `installer/ebb.ico`) is still the smooth red-capped lighthouse from before the art stages, off the palette. It can be redrawn from the logo's tower on the tide line; it touches the installer build, so it waits for your word.
- Whether the Harbour's hull top should step down from Iron light to Iron (a STYLE.md 10 change).
- Whether "large" text should get a hand-drawn Ledger at 10 or 12 px.
- Whether to flag the bosses `is_boss` (a gameplay change).
- The 3 % void shift; the hub's unlit village; hub floor warmth; tide line strength; foam at walls; Streets cobbles read; Hall floor flatness.
- Ebb ghost-or-figure; Wreck deck; Bell Ringer bear-or-person; Wrack Crab roundness; Violet light.

## Visual QA findings

### Stage 18 (the logo), found on review and fixed

1. **The tower read as a lowercase "i".** A straight 8-9 px shaft under a lit box, in front of "EBB", spelled "iEBB" at 1x. Fixed: the shaft tapers 7 to 15 px and stands on a 23 px Stone mound, so the silhouette is a tower before it is a stem.
2. **The reflection read as noise.** Scattering it pixel by pixel put speckle on the night sky. Fixed: it is a true mirror (each row samples the row two above), cut by wavelets that take whole runs of columns, stepping Shallow to Sea to Deep sea with depth.
3. **The letter ramp was chosen, not assumed.** Bone, Stone and Salt white were all drawn. Stone sinks into the sky; Salt is as cold as the moon and flattens the tide line; Bone reads at 1x and stays under the lamp. The sheet keeps the comparison.
4. **The lamp ray was drawn and cut.** A solid ray from the lamp over the letters reads as a stick, and the title's own turning beam is three metres to the right of it.

### Stage 20 (the composition pass)

- Found and fixed: the water rings (screen door), the silt lattice, the boss name under the strip, the currency over pale ground, the boss flash slab (which turned out to be overexposure, not the flash), the Hall citizen at 1.4:1 (the crown).
- Measured and left: Streets citizen 2.8:1; the neutral pool on cold floors; the transient text stack at a room's start; the hull top at the Harbour's edge.
- Then fixed at the source: the light knee in the sprite shader; the Bell keeps its tones with the lantern on it, hit frame included. HDR 2D was rejected because it moves 2D blending into linear space and would change every translucent overlay.

### Stage 19 (the asset library)

- People sheet: twelve people told apart at 1x by silhouette (the shawl, the child, the sou'wester, the cap and beard, the veil, the hat brim, the raised glass, the cold lantern, the hood, the tray); the drowned carry the crown rim, the kelp strand and the calm eyes; the portraits read at 1x in the slot.
- Enemies B sheet: each of the six has a distinct windup and attack silhouette; the humans' deaths are the knee, the lie, the sink; the swarm scatters; Tallow sags into his puddle; the Chainmother's chains-out frame and her fall read at 3x and at 1x in play.
- In play: the hub shows every person at 24 px and the beam turning from the lamp; the dialog shows Maren's portrait; the codex People tab shows each sprite; the Harbour room reads as deck, tar hull and quay with rope, bollard, netting and plank on it; the Chainmother stands in the flooded dock at 48 px with lit windows and a 24 px anchor; Tallow stands lit in a Hall alcove. No script errors in any shot.
- Fixed on review: the j of Stage 17 aside, this stage: the silt's tar pools read as plus signs (made irregular); the beam was invisible at energy 0.55 on a 128 px texture (now 256 px, slower fade, energy 1.0); the test counted eleven portraits (now twelve).
- Not judged in play: the eight new elite costumes, the small swarm, the vault open, the Shade's bolt in flight, the wax pool, the Choir and Netted named elites.

## Next visual task

On approval: Stage 22 (the full consistency audit: the ten biggest remaining inconsistencies, fixed in order of impact).
