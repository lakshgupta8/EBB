# Run headless tests.  Usage: .\tools\test.ps1
. "$PSScriptRoot\godot.ps1"
& $GodotExe --headless --path $ProjectRoot -s tests/run_tests.gd
exit $LASTEXITCODE
