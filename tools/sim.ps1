# Bot playtest of the combat sandbox.  Usage: .\tools\sim.ps1 [-Ticks 900]
param([int]$Ticks = 900)
. "$PSScriptRoot\godot.ps1"
& $GodotExe --headless --path $ProjectRoot tests/sim_combat.tscn -- "--ticks=$Ticks"
exit $LASTEXITCODE
