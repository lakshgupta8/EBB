# Balance harness: the bot plays every weapon at a few spring tides and writes one CSV row
# per run (depth reached, kills, damage taken, time, outcome).  Usage:
#   .\tools\balance.ps1 [-Ticks 9000] [-Tiers 0,4,8] [-Weapons gaff,net,harpoon,lantern,bell,line] [-Seed 1234]
# Output: tools/balance.csv (overwritten) and a summary table. Exit 1 if any run threw a script error.
param(
    [int]$Ticks = 9000,
    [int[]]$Tiers = @(0, 4, 8),
    [string[]]$Weapons = @("gaff", "net", "harpoon", "lantern", "bell", "line"),
    [int]$Seed = 1234
)
. "$PSScriptRoot\godot.ps1"
$out = Join-Path $ProjectRoot "tools\balance.csv"
$rows = @()
$errors = 0
foreach ($tier in $Tiers) {
    foreach ($w in $Weapons) {
        $log = & $GodotExe --headless --path "$ProjectRoot" tests/sim_run.tscn -- "--ticks=$Ticks" "--seed=$Seed" "--weapon=$w" "--fresh" "--tier=$tier" 2>&1 | Out-String
        if ($log -match "SCRIPT ERROR") { $errors++ }
        $m = [regex]::Match($log, "sim_run: ([0-9.]+)s\s+biome=(\d+)\s+depth=(\d+)\s+total=(\d+)\s+cleared=(\d+)\s+kills=(\d+)\s+salt=(\d+)\s+pearls=(\d+)\s+tide=([0-9.]+)\s+hp=(\d+)\s+ended=(\w+)\s+victory=(\w+)\s+taken=(\w+)")
        if (-not $m.Success) { Write-Host "no summary for $w tier $tier"; $errors++; continue }
        $rows += [pscustomobject]@{
            weapon = $w; tier = $tier; seconds = [double]$m.Groups[1].Value; biome = [int]$m.Groups[2].Value
            depth_total = [int]$m.Groups[4].Value; cleared = [int]$m.Groups[5].Value; kills = [int]$m.Groups[6].Value
            salt = [int]$m.Groups[7].Value; pearls = [int]$m.Groups[8].Value; hp = [int]$m.Groups[10].Value
            ended = $m.Groups[11].Value; victory = $m.Groups[12].Value
        }
        Write-Host ("{0,-8} tier {1}  depth {2,2}  kills {3,3}  hp {4,3}  ended {5}" -f $w, $tier, $m.Groups[4].Value, $m.Groups[6].Value, $m.Groups[10].Value, $m.Groups[11].Value)
    }
}
$rows | Export-Csv -Path $out -NoTypeInformation
$rows | Format-Table weapon, tier, depth_total, cleared, kills, salt, pearls, hp, ended | Out-String | Write-Host
Write-Host "wrote $out ($($rows.Count) runs, $errors errors)"
exit $(if ($errors -gt 0) { 1 } else { 0 })
