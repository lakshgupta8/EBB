# What the game asks for against what is on disk: sounds, music, sprites, dialog, rooms.
# Usage: .\tools\content.ps1      (exit 1 when something is missing)
. "$PSScriptRoot\godot.ps1"
& $GodotExe --headless --path $ProjectRoot tests/content_check.tscn
exit $LASTEXITCODE
