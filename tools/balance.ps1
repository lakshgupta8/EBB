# Balance harness: the bot plays every weapon at a few spring tides, on several seeds, and
# writes one CSV row per run (rooms reached, kills, time, how it ended). It also writes the
# pace the daily board measures itself against (data/par.json).
#
#   .\tools\balance.ps1 [-Ticks 30000] [-Seeds 3] [-Tiers 0,4,8] [-Weapons gaff,net,...]
#                       [-MinRooms 4] [-MinAvgRooms 8] [-MinWinRate 0] [-Fast 4]
#
# Green when, at tier 0, the bot averages -MinAvgRooms rooms a night, no single run falls
# under -MinRooms, nothing wedged in a room and nothing threw a script error. The average
# is what the gate leans on: one night's depth swings hugely from seed to seed, and a
# minimum would flap without anything having changed. -MinWinRate additionally demands
# that share of wins at tier 0; the bot does not play well enough to win a whole night
# today (it plays a fresh keeper with nothing bought), so the rate is reported, not gated.
# Output: tools/balance.csv, data/par.json, a summary table. Exit 1 when the table is red.
param(
    [int]$Ticks = 30000,
    [int]$Seeds = 3,
    [int[]]$Tiers = @(0, 4, 8),
    [string[]]$Weapons = @("gaff", "net", "harpoon", "lantern", "bell", "line"),
    [int]$MinRooms = 4,
    [int]$MinAvgRooms = 8,
    [int]$MinWinRate = 0,
    [int]$Fast = 4,
    [int]$Seed = 1234
)
. "$PSScriptRoot\godot.ps1"
$out = Join-Path $ProjectRoot "tools\balance.csv"
$par = Join-Path $ProjectRoot "data\par.json"
$rows = @()
$errors = 0
$total = $Tiers.Count * $Weapons.Count * $Seeds
$n = 0
foreach ($tier in $Tiers) {
    foreach ($w in $Weapons) {
        foreach ($s in 0..($Seeds - 1)) {
            $n++
            $runSeed = $Seed + $s * 101
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $log = & $GodotExe --headless --path "$ProjectRoot" tests/sim_run.tscn -- "--ticks=$Ticks" "--seed=$runSeed" `
                "--weapon=$w" "--fresh" "--tier=$tier" "--fast=$Fast" "--profile=bal_$w" 2>&1 | Out-String
            $sw.Stop()
            $wedged = $log -match "sim_run: WEDGED"
            if ($log -match "SCRIPT ERROR") {
                $errors++
                Write-Host "SCRIPT ERROR in $w tier $tier seed $runSeed" -ForegroundColor Red
            }
            $m = [regex]::Match($log, "sim_run: ([0-9.]+)s\s+biome=(\d+)\s+depth=(\d+)\s+total=(\d+)\s+cleared=(\d+)\s+kills=(\d+)\s+salt=(\d+)\s+pearls=(\d+)\s+tide=([0-9.]+)\s+hp=(\d+)\s+ended=(\w+)\s+victory=(\w+)\s+taken=(\w+)")
            if (-not $m.Success) { Write-Host "no summary for $w tier $tier seed $runSeed"; $errors++; continue }
            $rooms = [int]$m.Groups[4].Value + 1
            $seconds = [double]$m.Groups[1].Value
            $victory = $m.Groups[12].Value -eq "true"
            $rows += [pscustomobject]@{
                weapon = $w; tier = $tier; seed = $runSeed; seconds = $seconds; biome = [int]$m.Groups[2].Value
                rooms = $rooms; cleared = [int]$m.Groups[5].Value; kills = [int]$m.Groups[6].Value
                salt = [int]$m.Groups[7].Value; pearls = [int]$m.Groups[8].Value; tide = [double]$m.Groups[9].Value
                hp = [int]$m.Groups[10].Value; victory = $victory
                cause = $(if ($wedged) { "wedged" } elseif ($victory) { "won" } elseif ($m.Groups[13].Value -eq "true") { "tide" } elseif ($m.Groups[11].Value -eq "true") { "deep" } else { "budget" })
                real = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            }
            Write-Host ("[{0,3}/{1,3}] {2,-8} tier {3}  seed {4,-6} rooms {5,3}  kills {6,3}  {7,6:N0}s  {8}" -f `
                $n, $total, $w, $tier, $runSeed, $rooms, $m.Groups[6].Value, $seconds, $rows[-1].cause)
        }
    }
}
if ($rows.Count -eq 0) { Write-Host "no runs"; exit 1 }
$rows | Export-Csv -Path $out -NoTypeInformation

# Per weapon and tier: how far it got, how long it took, how it ended.
Write-Host ""
$rows | Group-Object weapon, tier | ForEach-Object {
    $g = $_.Group
    [pscustomobject]@{
        weapon = $g[0].weapon; tier = $g[0].tier
        rooms_min = ($g | Measure-Object rooms -Minimum).Minimum
        rooms_avg = [math]::Round(($g | Measure-Object rooms -Average).Average, 1)
        kills_avg = [math]::Round(($g | Measure-Object kills -Average).Average, 1)
        secs_avg = [math]::Round(($g | Measure-Object seconds -Average).Average, 0)
        wins = ($g | Where-Object victory).Count
        of = $g.Count
        ends = (($g | Group-Object cause | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join " ")
    }
} | Format-Table | Out-String | Write-Host

# The pace the daily board draws its bar against: seconds a room, from the tier-0 runs.
$base = $rows | Where-Object { $_.tier -eq 0 }
$perRoom = [math]::Round((($base | ForEach-Object { $_.seconds / [math]::Max(1, $_.rooms) }) | Measure-Object -Average).Average, 2)
@{ seconds_per_room = $perRoom; measured = (Get-Date -Format "yyyy-MM-dd"); runs = $base.Count } |
    ConvertTo-Json | Set-Content -Path $par -Encoding utf8
Write-Host "par: $perRoom seconds a room (from $($base.Count) runs at tier 0) -> data\par.json"

# The gate.
$red = @()
if ($errors -gt 0) { $red += "$errors runs threw a script error" }
$stuck = $rows | Where-Object { $_.cause -eq "wedged" }
if ($stuck) { $red += "$($stuck.Count) runs wedged in a room ($(($stuck | ForEach-Object { "$($_.weapon)@$($_.rooms)" }) -join ', '))" }
$short = $base | Where-Object { $_.rooms -lt $MinRooms }
if ($short) { $red += "$($short.Count) tier-0 runs stopped before room $MinRooms ($(($short | ForEach-Object { "$($_.weapon)@$($_.rooms)" }) -join ', '))" }
$avgRooms = [math]::Round(($base | Measure-Object rooms -Average).Average, 1)
Write-Host "tier-0 rooms: $avgRooms on average, $((($base | Measure-Object rooms -Minimum).Minimum)) at worst, $((($base | Measure-Object rooms -Maximum).Maximum)) at best  (gate: $MinAvgRooms average)"
if ($avgRooms -lt $MinAvgRooms) { $red += "tier-0 average $avgRooms rooms is under $MinAvgRooms" }
$winRate = [math]::Round(100.0 * (($base | Where-Object victory).Count) / [math]::Max(1, $base.Count), 1)
Write-Host "tier-0 win rate: $winRate%  (gate: $MinWinRate%)"
if ($winRate -lt $MinWinRate) { $red += "tier-0 win rate $winRate% is under $MinWinRate%" }
Write-Host "wrote $out ($($rows.Count) runs)"
if ($red.Count -gt 0) {
    foreach ($r in $red) { Write-Host "RED: $r" -ForegroundColor Red }
    exit 1
}
Write-Host "balance table: green" -ForegroundColor Green
exit 0
