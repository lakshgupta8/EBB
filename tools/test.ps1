# Run headless tests.  Usage: .\tools\test.ps1
. "$PSScriptRoot\godot.ps1"
& $GodotExe --headless --path $ProjectRoot tests/run_tests.tscn
exit $LASTEXITCODE
