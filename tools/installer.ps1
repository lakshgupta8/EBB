# Builds the game and wraps it in dist\EBB-Setup-<version>.exe: one file to double-click
# that puts EBB on a drive, leaves a launcher on the desktop and an uninstaller beside the
# game. Running a newer setup over an older install updates it in place.
#
#   .\tools\installer.ps1              build the game, then the installer
#   .\tools\installer.ps1 -SkipBuild   wrap whatever is already in dist\EBB.exe
#   .\tools\installer.ps1 -SelfTest    also install to a temp folder and uninstall again,
#                                      to prove both halves work without touching yours
#
# The version comes from Game.VERSION in src\core\game.gd, so the title screen, the exe's
# file properties, the setup file name and Apps & features all say the same number.
param(
    [switch]$SkipBuild,
    [switch]$SelfTest,
    [string]$Version
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"

if (-not $Version) { $Version = Get-EbbVersion }
# Inno Setup compiles the installer. It is the only extra tool this needs; fetch it once.
function Find-ISCC {
    $paths = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    $cmd = Get-Command ISCC -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}
$iscc = Find-ISCC
if (-not $iscc) {
    Write-Host "Inno Setup not found; installing it with winget..."
    winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements
    $iscc = Find-ISCC
    if (-not $iscc) { throw "Inno Setup still not found. Install it from https://jrsoftware.org/isdl.php" }
}

$icon = Join-Path $ProjectRoot "installer\ebb.ico"
if (-not (Test-Path $icon)) {
    Write-Host "Drawing the icon..."
    python (Join-Path $ProjectRoot "tools\gen_icon.py")
    if ($LASTEXITCODE -ne 0) { throw "icon generation failed" }
}

$exe = Join-Path $ProjectRoot "dist\EBB.exe"
if ($SkipBuild) {
    if (-not (Test-Path $exe)) { throw "-SkipBuild, but dist\EBB.exe is not there yet" }
} else {
    & (Join-Path $PSScriptRoot "export.ps1") -Version $Version
}

Write-Host "Compiling the installer (EBB $Version)..."
& $iscc "/DAppVersion=$Version" (Join-Path $ProjectRoot "installer\ebb.iss")
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
$setup = Join-Path $ProjectRoot "dist\EBB-Setup-$Version.exe"
if (-not (Test-Path $setup)) { throw "ISCC said it was fine but $setup is missing" }
Write-Host ("{0}  ({1:N0} MB)" -f $setup, ((Get-Item $setup).Length / 1MB)) -ForegroundColor Green

$InstalledKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{1E6307C6-7D96-4CDE-B1CC-0405071EF26E}_is1"
if ($SelfTest) {
    # Install to a scratch folder with no shortcuts, check what landed, then uninstall and
    # check it all went. Nothing here touches the desktop or the saves. It would, though,
    # walk over a real install: same installer, same record in Apps & features. So when EBB
    # is already installed, say so and stop rather than quietly unregister it.
    if (Test-Path $InstalledKey) {
        $where = (Get-ItemProperty $InstalledKey).InstallLocation
        Write-Host "Skipping the self-test: EBB is already installed at $where, and the test" -ForegroundColor Yellow
        Write-Host "would take over its entry in Apps & features." -ForegroundColor Yellow
        return
    }
    $tmp = Join-Path $env:TEMP "ebb_setup_selftest"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Write-Host "Self-test: installing to $tmp ..."
    $p = Start-Process $setup -ArgumentList "/SILENT", "/NOICONS", "/NORESTART", "/SUPPRESSMSGBOXES", "/DIR=$tmp" -PassThru
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "the installer did not finish in 5 minutes" }
    if ($p.ExitCode -ne 0) { throw "the installer exited with $($p.ExitCode)" }
    $unins = Join-Path $tmp "unins000.exe"
    foreach ($f in @((Join-Path $tmp "EBB.exe"), $unins)) {
        if (-not (Test-Path $f)) { throw "self-test: $f was not installed" }
        Write-Host ("  installed {0,-12} {1:N0} MB" -f (Split-Path $f -Leaf), ((Get-Item $f).Length / 1MB))
    }
    Write-Host "Self-test: uninstalling..."
    # The uninstaller re-launches itself from %TEMP% and the first process exits at once,
    # so wait for the folder to go rather than for the process.
    Start-Process $unins -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" | Out-Null
    $deadline = (Get-Date).AddSeconds(120)
    while ((Test-Path $tmp) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (Test-Path $tmp) { throw "self-test: $tmp is still there after uninstalling" }
    if (Test-Path $InstalledKey) { throw "self-test: the Apps & features entry survived the uninstall" }
    Write-Host "Self-test: installed and uninstalled cleanly." -ForegroundColor Green
}
