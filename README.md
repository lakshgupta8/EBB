# EBB

Top-down action roguelite. Keep the tide. See [DESIGN.md](DESIGN.md).

## Requirements
- Godot 4.7.2 (`winget install GodotEngine.GodotEngine`)
- Python 3 + Pillow + numpy/scipy (asset generation only)

## Commands
| What | Command |
|---|---|
| Run the game | `.\tools\run.ps1` |
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
| Esc / F11 | pause / fullscreen toggle. The pause menu has Give up [Q] and Quit game [X] |
| 1-9 or click | pick in any menu; E / Esc / right-click leaves |

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
Beating the Ebb wins the night and brings Maren home. Endings are M5.

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
| Maren | under the Ebb | talks; the endings come in M5 |

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
