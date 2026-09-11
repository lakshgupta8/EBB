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
| Open Godot editor | `.\tools\editor.ps1` |

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
