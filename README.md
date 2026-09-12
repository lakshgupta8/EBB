# EBB

Top-down action roguelite. Keep the tide. See [DESIGN.md](DESIGN.md).

## Requirements
- Godot 4.7.2 (`winget install GodotEngine.GodotEngine`)
- Python 3 + Pillow + numpy/scipy (asset generation only)

## Commands
| What | Command |
|---|---|
| Run the game | `.\tools\run.ps1` (title screen; `.\tools\run.ps1 src/hub/hub.tscn` skips it) |
| Build the Windows .exe | `.\tools\export.ps1` (fetches the 4.7.2 export templates once, ~1 GB) -> `dist\EBB.exe` |
| Jump to a biome / its boss | `.\tools\run.ps1 -- --biome=1` (streets), `--biome=2` (hall), add `--boss` |
| Run tests (headless) | `.\tools\test.ps1` |
| Bot playtest (headless) | `.\tools\sim.ps1 -Ticks 40000 -Seed 5 -Weapon harpoon [-Fresh]` (gaff, net, harpoon, lantern) |
| Regenerate sprites / rooms / audio | `python tools\gen_sprites.py --preview`, `python tools\gen_rooms.py`, `python tools\gen_audio.py` |
| Open Godot editor | `.\tools\editor.ps1` |

## Controls
| Input | Action |
|---|---|
| WASD / mouse | move / aim |
| LMB | attack (weapon combo; hold to keep going) |
| LMB hold (gaff) | keep holding to charge; when the hook rings, release for a heavy sweep that cracks shells (double damage for 3 s). Release early: nothing happens |
| Space, then LMB | lunge out of the dash |
| Space through an attack | riptide: slow-mo, dash refunded, next hit crits |
| RMB | weapon special: hook throw (gaff) or net throw (knife) |
| Q | lantern flare when the glow meter is full (hits charge it): stuns and damages everything nearby |
| E | interact (fountains, chests, cages, people, results screen) |
| Esc / F11 | pause / fullscreen toggle. The pause menu has Codex [C], Settings [S], Rest here [R], Give up [Q] / Back to the title [T], Quit game [X] |
| R (paused) | rest: once a room is cleared and its doors are open, the night is saved and you go back up. The shore continues it next time, once; the tide, your health, salt and tidemarks are exactly as you left them |
| C | the codex: the drowned, tidemarks, people and places you have met |
| 1-9 or click | pick in any menu; arrows / WASD move a highlight, Enter picks it; E / Esc / right-click leaves |

### Gamepad
Left stick moves, right stick aims (tilt further to throw further; without it you aim where you walk).
A dash, X or right trigger attack, Y or left trigger special, LB flare, B use / talk / leave, Start pause,
Back codex. Menus: d-pad or stick to highlight, A picks, B leaves. Prompts switch to pad buttons the
moment a pad is used.

### Settings
From the pause menu or the title: master / music / sound volume, screen shake (off, low, full), screen
flashes, fullscreen. Saved to `user://settings.json`.

Knocking an enemy into a wall deals bonus damage. Enemies flash white and ring right
before they strike: dash on the flash for a riptide.

## Weapons (M4)
| Weapon | LMB | RMB |
|---|---|---|
| Gaff Hook (start) | 3-hit combo, third hit pulls; hold until it rings, then release for a heavy sweep | throw: light enemies are dragged to you, heavy ones drag you to them |
| Net & Knife (Bram's gift) | four fast stabs, the fourth cuts deep and bleeds; you stay mobile | throw a net at the cursor: everything under it is rooted for 2 s and takes +25% |
| Harpoon Gun (25 pearls) | piercing bolts, three then a reload; hold to keep firing | tether an enemy: every dash you make drags it along; bosses barely move |
| Storm Lantern (40 pearls) | wide quick arcs of light; everything hit is LIT (+30% damage from anything) and charges the flare fast | beacon: a pool of light at the cursor that lits and slows what stands in it |

Pick and forge weapons at Bram's forge on Marrow Rock. The HUD shows the harpoon's ammo next to the special bar.

## The night (M4)
Hub (lighthouse) -> The Flats (8 rooms + The Wreck) -> slack water -> The Drowned Streets
(9 rooms + The Bell of Saltmere) -> slack water -> The Deep Hall (7 rooms + The Ebb).
Beating the Ebb wins the night and brings Maren home to the lighthouse, where she holds the endings.
A night can be rested at any cleared room (pause, Rest here) and continued from the shore later.
Bot check of the same: `.\tools\sim.ps1 -RestAt 3` rests at depth 3, resumes, and compares every field.

## Story (M5)
- **The lantern whispers.** One-time lines during a run, at the first night, the first cage, each
  boss and each biome, and on the results card the first time you die or are taken. They tell the
  truth in layers. Lines live in `src/story/story.gd`, with everything anyone says at the hub.
- **Endings.** Talk to Maren after the Ebb falls. *Keep the tide* is always open. *Break the tide*
  needs Bram, Wren and the Cartographer on the rock. *Walk out* appears once everyone is home and
  opens after three nights won. Each plays out over black with the sea rising or falling behind the
  words, is remembered on the profile, and can be chosen again; the people on the rock change what
  they say afterwards.
- **Codex.** C, or from the pause menu. Enemies fill in when first seen, tidemarks when first offered,
  people as they come home, places as you reach them. Every entry has a line of lore.
- **Fen** stands on the rock too: the village kid, only ever has something to say.

To watch an ending without earning it: `.	ools
un.ps1 src/hub/hub.tscn -- --screenshot --sim-save --ending=break`
(the `--sim-save` profile, never yours).

- The tide meter on the right rises with time and every room; low ground floods first, then the
  rest. Shallow water slows you, deep water hurts. It falls back to slack water after a boss.
- Door signboards show what is behind each exit: combat, elite, fountain, chest, merchant, altar,
  echo (a cage), boss.
- **Echo rooms** hold one of the drowned in a cage. Clear the guards, open the cage with E, and they
  go ahead of you to the lighthouse. Rescues are kept even if the run ends.
- Dying keeps pearls; being taken by the tide also converts half your salt to pearls.

### Who you can bring back
| Echo | Found | At the lighthouse |
|---|---|---|
| Bram the Drowned | The Flats, an echo room | forge: choose your weapon |
| Sister Wren | The Drowned Streets | bless a tidemark family: every altar offers one from it |
| The Cartographer | The Drowned Streets (after Wren) | chart a room: fountain, chest or merchant guaranteed two rooms into every biome |
| Maren | under the Ebb | the endings: keep, break, or walk out |

### Streets enemies
Still Citizen (statue until you are close, then fast), Lamplighter (kindles the others; throws its
lantern when alone; kill first), Bell Ringer (long tell, shockwave, calls the drowned up out of
the water), Swimmer (fast in water, slow on stone). The Bell of Saltmere tolls a ring of sound,
swings, and peals three times; at half health the statues in the square wake.

### Hall enemies
Keeper's Shade (fights with a dark copy of whatever weapon you carry, then slips away), Anchor
(throws a chain from a way off: dash through it or be hauled in for the slam), Deep Maw (a mouth
in the floor; opens when you are near, hangs open and vulnerable after it bites). Elites here are
Echoes of Maren. The Ebb sends walls of water with one gap, hauls you in and slams, calls shades,
and rises twice.

## Music and art (M5)
Five procedural loops in `tools/gen_music.py` (hub, flats, streets, hall, boss), on their own bus.
The title screen, enemy bodies that squash and fade, and the keeper falling when the night ends
are the M5 polish pass; every sprite is still drawn by `tools/gen_sprites*.py`.

## Progression
- Tidemarks: 42 per-run boons in four families (salt = offence, brine = defence, current = mobility,
  deep = weird). Defined in `src/tidemarks/tidemarks.gd`; they write into `Player.mods`.
- Ledger: permanent tiers bought from Orla with pearls. Defined in `src/hub/ledger.gd`.
- Save: `user://save.json` (pearls, ledger, story flags, weapons forged, blessing, chart).

Sandbox arena for feel tuning: `.\tools\run.ps1 src/sandbox.tscn`

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
Room templates are ASCII in `tools/gen_rooms*.py` (legend at the top); every open cell must be
reachable from the spawn, and the test suite checks it.
