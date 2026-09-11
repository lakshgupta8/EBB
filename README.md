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
WASD move, mouse aim, LMB swing (3-hit combo, third hit pulls), RMB hook throw (yank to target),
Space dash, E interact (fountains, chests, results screen).

## Flow (M2)
Hub (lighthouse) -> walk to the water's edge -> 8 rooms of The Flats chosen door by door -> boss.
The tide meter on the right rises with time and every room; low ground floods first, then sand.
Shallow water slows you, deep water hurts. Dying keeps pearls; being taken by the tide also
converts half your salt to pearls.

Sandbox arena for feel tuning: `.\tools\run.ps1 src/sandbox.tscn`

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
