# Open the project in the Godot editor.  Usage: .\tools\editor.ps1
. "$PSScriptRoot\godot.ps1"
Start-Process $GodotExe -ArgumentList "--editor", "--path", "`"$ProjectRoot`""
