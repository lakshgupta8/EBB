# The measurement matrix for the report: RTT {0, 50, 100, 200 ms} x loss {0, 2, 5 %}.
# Conditions go on the guest only, so the round trip is twice the one-way latency set here, and
# each direction loses packets at the stated rate once. One co-op bot night per cell.
#   .\tools\net_bench.ps1 [-Ticks 1500]     writes docs\net\measurements.csv
param([int]$Ticks = 1500, [int]$BasePort = 24700)
. "$PSScriptRoot\godot.ps1"
$out = Join-Path $ProjectRoot "docs\net"
New-Item -ItemType Directory -Force $out | Out-Null
$csv = Join-Path $out "measurements.csv"
"rtt_target_ms,loss_pct,rtt_ms,bytes_in_per_s,bytes_out_per_s,snaps_per_s,corrections_per_s,mean_correction_px,max_error_px,snap_corrections,underruns_per_s,rooms,result" | Set-Content $csv
$port = $BasePort
foreach ($rtt in 0, 50, 100, 200) {
    foreach ($loss in 0, 2, 5) {
        $port++
        $lat = [int]($rtt / 2)
        $jit = [Math]::Min(20, [int]($rtt / 10))
        $cond = if ($rtt -eq 0 -and $loss -eq 0) { "" } else { "$lat,$jit,$($loss / 100.0)" }
        $tmp = Join-Path $env:TEMP "ebb_bench_${rtt}_${loss}"
        $args = @{ Ticks = $Ticks; Port = $port; Out = $tmp; GuestOnly = $true }
        if ($cond) { $args.NetSim = $cond }
        "== rtt $rtt ms, loss $loss % ($cond)"
        & "$PSScriptRoot\net_sim.ps1" @args | Out-Null
        $line = Get-Content (Join-Path $tmp "guest.out") | Select-String "sim_net_guest: summary" | Select-Object -Last 1
        $ok = (Get-Content (Join-Path $tmp "guest.out") | Select-String "sim_net_guest: OK") -ne $null
        if ($line) {
            $m = @{}
            [regex]::Matches($line.Line, '(\w+)=([-\d\.]+)') | ForEach-Object { $m[$_.Groups[1].Value] = $_.Groups[2].Value }
            "$rtt,$loss,$($m.rtt),$($m.bytes_in),$($m.bytes_out),$($m.snaps_per_s),$($m.corrections),$($m.mean_correction),$($m.max_error),$($m.snaps),$($m.underruns),$($m.rooms),$(if ($ok) { 'pass' } else { 'FAIL' })" | Add-Content $csv
        } else {
            "$rtt,$loss,,,,,,,,,,,NO-DATA" | Add-Content $csv
        }
    }
}
Get-Content $csv
