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

## Controls (M1 sandbox)
WASD move, mouse aim, LMB swing (3-hit combo, third hit pulls), RMB hook throw (yank to target), Space dash, R restart.

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
