# EBB

Top-down action roguelite. Keep the tide. See [DESIGN.md](DESIGN.md).

## Requirements
- Godot 4.7.2 (`winget install GodotEngine.GodotEngine`)
- Python 3 + Pillow (asset generation only)

## Commands
| What | Command |
|---|---|
| Run the game | `.\tools\run.ps1` |
| Run tests (headless) | `.\tools\test.ps1` |
| Bot playtest (headless) | `.\tools\sim.ps1 -Ticks 1800` |
| Regenerate sprites | `python tools\gen_sprites.py --preview` |
| Open Godot editor | `.\tools\editor.ps1` |

## Controls
| Input | Action |
|---|---|
| WASD / mouse | move / aim |
| LMB tap | 3-hit combo; the third hit pulls enemies in |
| LMB hold | after a swing, keep holding to charge a heavy sweep: cracks shells (double damage for 3 s) |
| Space, then LMB | lunge out of the dash |
| Space through an attack | riptide: slow-mo, dash refunded, next hit crits |
| RMB | hook throw, yank to whatever it catches |
| Q | lantern flare when the glow meter is full (hits charge it): stuns and damages everything nearby |
| E | interact (fountains, chests, results screen) |
| Esc / F11 | pause / fullscreen toggle |

Knocking an enemy into a wall deals bonus damage.

## Flow (M2)
Hub (lighthouse) -> walk to the water's edge -> 8 rooms of The Flats chosen door by door -> boss.
The tide meter on the right rises with time and every room; low ground floods first, then sand.
Shallow water slows you, deep water hurts. Dying keeps pearls; being taken by the tide also
converts half your salt to pearls.

Sandbox arena for feel tuning: `.\tools\run.ps1 src/sandbox.tscn`

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
