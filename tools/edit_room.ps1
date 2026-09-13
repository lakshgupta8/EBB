# The room editor, behind a dev flag: paint a template, see the room rebuild, save it back.
#   .\tools\edit_room.ps1 [-Room data/rooms/biome1/flats_01.txt]
# Mouse paints; right button clears. S saves (it refuses a room you cannot walk around),
# L reloads, Tab picks a brush, [ and ] step through the biome's files, Esc quits.
param([string]$Room = "data/rooms/biome1/flats_01.txt")
. "$PSScriptRoot\godot.ps1"
& $GodotExe --path $ProjectRoot src/dev/room_editor.tscn -- "--room=$Room"
exit $LASTEXITCODE
