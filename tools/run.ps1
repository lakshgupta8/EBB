# Run the game.  Usage: .\tools\run.ps1 [extra godot args]
. "$PSScriptRoot\godot.ps1"
& $GodotExe --path $ProjectRoot @args
# Tip: .\tools\run.ps1 -- --screenshot   saves .shots/latest.png and quits
