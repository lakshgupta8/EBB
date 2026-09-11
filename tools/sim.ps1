# Bot playtests.  Usage: .\tools\sim.ps1 [-Scene run|combat] [-Ticks 6000] [-Seed 1234]
param([string]$Scene = "run", [int]$Ticks = 6000, [int]$Seed = 1234, [string]$Weapon = "gaff", [switch]$Fresh)
. "$PSScriptRoot\godot.ps1"
$target = if ($Scene -eq "combat") { "tests/sim_combat.tscn" } else { "tests/sim_run.tscn" }
$extra = @("--weapon=$Weapon")
if ($Fresh) { $extra += "--fresh" }
& $GodotExe --headless --path $ProjectRoot $target -- "--ticks=$Ticks" "--seed=$Seed" @extra
exit $LASTEXITCODE
