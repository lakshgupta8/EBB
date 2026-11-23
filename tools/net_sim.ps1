# Co-op integration run: a host bot and a guest bot, two Godot processes, real UDP on loopback.
#   .\tools\net_sim.ps1 [-Ticks 2400] [-Port 24680] [-NetSim "100,20,0.05"] [-Seed 1234]
# Exit 0 when the guest bot says OK and neither process printed a script error.
param([int]$Ticks = 2400, [int]$Port = 24680, [string]$NetSim = "", [int]$Seed = 1234, [string]$Out = "", [string]$Mode = "coop")
. "$PSScriptRoot\godot.ps1"
$tmp = if ($Out) { $Out } else { Join-Path $env:TEMP "ebb_net_sim" }
New-Item -ItemType Directory -Force $tmp | Out-Null
$h = @('--headless', '--path', $ProjectRoot, 'tests/sim_run.tscn', '--', "--ticks=$Ticks", "--seed=$Seed", '--weapon=gaff', '--fresh', '--sturdy', "--mp-host=$Port", '--profile=net_sim_host')
$g = @('--headless', '--path', $ProjectRoot, 'tests/sim_net_guest.tscn', '--', '--connect=127.0.0.1', "--port=$Port", "--ticks=$($Ticks * 2)")
if ($Mode -eq 'pvp') {
    $h = @('--headless', '--path', $ProjectRoot, 'tests/sim_pvp_host.tscn', '--', "--port=$Port", "--max-ticks=$($Ticks * 6)")
    $g = @('--headless', '--path', $ProjectRoot, 'tests/sim_net_guest.tscn', '--', '--connect=127.0.0.1', "--port=$Port", "--ticks=$($Ticks * 6)", '--mode=pvp')
}
if ($NetSim) { $h += "--netsim=$NetSim"; $g += "--netsim=$NetSim" }
$ho = Join-Path $tmp "host.out"
$go = Join-Path $tmp "guest.out"
$hp = Start-Process $GodotExe -ArgumentList $h -RedirectStandardOutput $ho -RedirectStandardError "$ho.err" -PassThru -NoNewWindow
Start-Sleep -Seconds 3
$gp = Start-Process $GodotExe -ArgumentList $g -RedirectStandardOutput $go -RedirectStandardError "$go.err" -PassThru -NoNewWindow
$limit = [Math]::Max(240000, $Ticks * 40)
if (-not $gp.WaitForExit($limit)) { $gp.Kill(); "guest TIMEOUT" }
if (-not $hp.WaitForExit(60000)) { $hp.Kill(); "host TIMEOUT (killed)" }
Get-Content $ho | Select-String "sim_net_host|sim_pvp_host|sim_run: .*cleared" | ForEach-Object { $_.Line }
Get-Content $go | Select-String "sim_net_guest" | ForEach-Object { $_.Line }
$errs = @(Get-Content "$ho.err", "$go.err" -ErrorAction SilentlyContinue | Select-String "SCRIPT ERROR")
if ($errs.Count) { "SCRIPT ERRORS:"; $errs | Select-Object -First 8 | ForEach-Object { $_.Line } }
$ok = ((Get-Content $go | Select-String "sim_net_guest: OK") -ne $null) -and ($errs.Count -eq 0)
if ($Mode -eq 'pvp') {
    $hw = (Get-Content $ho | Select-String "wins=\[(\d+), (\d+)\]")
    $gw = (Get-Content $go | Select-String "pvp_wins=\((\d+),(\d+)\)")
    if (-not $hw -or -not $gw) { "pvp: could not compare the two scores"; $ok = $false }
    elseif ($hw.Matches[0].Groups[1].Value -ne $gw.Matches[0].Groups[1].Value -or $hw.Matches[0].Groups[2].Value -ne $gw.Matches[0].Groups[2].Value) { "pvp: the two sides disagree on the score: host $($hw.Matches[0].Value) guest $($gw.Matches[0].Value)"; $ok = $false }
    else { "pvp: both sides agree on the score " + $hw.Matches[0].Value }
}
"net_sim: " + $(if ($ok) { "PASS" } else { "FAIL" }) + "   (logs in $tmp)"
exit $(if ($ok) { 0 } else { 1 })
