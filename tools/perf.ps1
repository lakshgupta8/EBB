# Performance in the large rooms (map Stage 13b): the bot plays with a window at real speed,
# vsync off, and tests/perf_probe.gd times every frame room by room.
#
#   .\tools\perf.ps1 [-Seconds 40] [-Crowd 10] [-Tide 2.0] [-Night]
#
# Cases: in each biome the wettest 80x46 room (every fight is that room, the first at -Tide,
# topped up to -Crowd enemies), then the generator in each biome the same way. -Night adds a
# whole night on each road at real speed (about a quarter of an hour each), bosses and all.
# Green when no room's 99th-percentile frame passes -BudgetMs and no way into a room (after
# the first, which is the game loading) holds the screen longer than -EntryMs. 400 ms: a generated
# 80x46 room takes about a third of a second, all of it under the black (map Stage 13b).
# Output: tools/perf.csv and a summary. Exit 1 when red. Never run it beside a bot or a shot.
param(
    [int]$Seconds = 40,
    [int]$Crowd = 10,
    [double]$Tide = 2.0,
    [switch]$Night,
    [double]$BudgetMs = 16.7,
    [double]$EntryMs = 400,
    [int]$Seed = 11
)
. "$PSScriptRoot\godot.ps1"
$out = Join-Path $ProjectRoot "tools\perf.csv"
$tmp = Join-Path $env:TEMP "ebb_perf"
New-Item -ItemType Directory -Force $tmp | Out-Null
$ticks = $Seconds * 60
$big = @(
    @{ biome = 0; room = "data/rooms/biome1/flats_08.txt" },
    @{ biome = 1; room = "data/rooms/harbour/harbour_06.txt" },
    @{ biome = 2; room = "data/rooms/biome2/streets_10.txt" },
    @{ biome = 3; room = "data/rooms/biome3/hall_07.txt" },
    @{ biome = 4; room = "data/rooms/reef/reef_10.txt" }
)
$cases = @()
foreach ($b in $big) {
    $cases += @{ name = "big-b$($b.biome)"; args = @("--biome=$($b.biome)", "--room=$($b.room)", "--tide=$Tide", "--crowd=$Crowd", "--ticks=$ticks") }
}
foreach ($i in 0..4) {
    $cases += @{ name = "gen-b$i"; args = @("--biome=$i", "--gen", "--tide=$Tide", "--crowd=$Crowd", "--ticks=$($ticks * 2)") }
}
if ($Night) {
    $cases += @{ name = "night-harbour"; args = @("--road=harbour", "--ticks=60000") }
    $cases += @{ name = "night-reef"; args = @("--road=reef", "--ticks=60000") }
}
$rows = @()
$spikeCount = 0
$errors = 0
$adapter = ""
foreach ($c in $cases) {
    $log = Join-Path $tmp "$($c.name).log"
    $argv = @("--path", "`"$ProjectRoot`"", "tests/sim_run.tscn", "--", "--perf", "--sturdy", "--fresh", "--profile=perf", "--seed=$Seed") + $c.args
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Start-Process -Wait -NoNewWindow -FilePath $GodotExe -ArgumentList $argv -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $sw.Stop()
    $text = Get-Content $log -Raw
    if ($text -match "SCRIPT ERROR") { $errors++; Write-Host "SCRIPT ERROR in $($c.name) (log: $log)" -ForegroundColor Red }
    $a = [regex]::Match($text, "perf: (.+), window")
    if ($a.Success) { $adapter = $a.Groups[1].Value }
    $first = $true
    foreach ($m in [regex]::Matches($text, "perf: (\S+) (\d+x\d+) (\S+) frames=(\d+) avg=([0-9.]+) p50=([0-9.]+) p95=([0-9.]+) p99=([0-9.]+) max=([0-9.]+) entry=([0-9.]+) gpu=([0-9.]+) gpu95=([0-9.]+) draws95=(\d+) enemies=(\d+) flooded=(\d+) nodes=(\d+)")) {
        $g = $m.Groups
        $rows += [pscustomobject]@{
            case = $c.name; room = $g[1].Value; size = $g[2].Value; type = $g[3].Value; frames = [int]$g[4].Value
            avg = [double]$g[5].Value; p50 = [double]$g[6].Value; p95 = [double]$g[7].Value; p99 = [double]$g[8].Value
            max = [double]$g[9].Value; entry = $(if ($first) { $null } else { [double]$g[10].Value })
            gpu = [double]$g[11].Value; gpu95 = [double]$g[12].Value; draws95 = [int]$g[13].Value
            enemies = [int]$g[14].Value; flooded = [int]$g[15].Value; nodes = [int]$g[16].Value
        }
        $first = $false
    }
    $mine = $rows | Where-Object { $_.case -eq $c.name }
    # A frame over 33 ms inside a room is printed as it happens (two frames lost at 60 fps).
    $spikes = [regex]::Matches($text, "perf-spike: ([0-9.]+) ms") | ForEach-Object { [double]$_.Groups[1].Value }
    $script:spikeCount += @($spikes).Count
    Write-Host ("{0,-14} {1,3} rooms  worst p99 {2,6:N2} ms  worst max {3,7:N1} ms  {4} frames over 33 ms  ({5:N0} s)" -f $c.name, @($mine).Count,
        ($mine | Measure-Object p99 -Maximum).Maximum, ($mine | Measure-Object max -Maximum).Maximum, @($spikes).Count, $sw.Elapsed.TotalSeconds)
}
if ($rows.Count -eq 0) { Write-Host "no rooms measured"; exit 1 }
$rows | Export-Csv -Path $out -NoTypeInformation
Write-Host ""
Write-Host "on $adapter"
$rows | Sort-Object p99 -Descending | Select-Object -First 12 case, room, size, type, avg, p95, p99, max, entry, gpu95, draws95, enemies, flooded |
    Format-Table | Out-String | Write-Host
$entries = $rows | Where-Object { $_.entry -ne $null }
Write-Host ("frame: {0:N2} ms on average, p99 {1:N2} at worst; way in: {2:N0} ms at worst over {3} rooms" -f `
    ($rows | Measure-Object avg -Average).Average, ($rows | Measure-Object p99 -Maximum).Maximum,
    ($entries | Measure-Object entry -Maximum).Maximum, @($entries).Count)
Write-Host "frames over 33 ms inside a room: $spikeCount"
$red = @()
if ($errors -gt 0) { $red += "$errors cases threw a script error" }
$slow = $rows | Where-Object { $_.p99 -gt $BudgetMs }
if ($slow) { $red += "$(@($slow).Count) rooms with a p99 frame over $BudgetMs ms ($(($slow | ForEach-Object { $_.room }) -join ', '))" }
$hitch = $entries | Where-Object { $_.entry -gt $EntryMs }
if ($hitch) { $red += "$(@($hitch).Count) ways in over $EntryMs ms ($(($hitch | ForEach-Object { "$($_.room) $($_.entry)" }) -join ', '))" }
Write-Host "wrote $out ($($rows.Count) rooms)"
if ($red.Count -gt 0) {
    foreach ($r in $red) { Write-Host "RED: $r" -ForegroundColor Red }
    exit 1
}
Write-Host "performance: green" -ForegroundColor Green
exit 0
