# Build the Windows executable into dist\EBB.exe.  Usage: .\tools\export.ps1 [-Version 1.2.0]
# Fetches the 4.7.2 export templates the first time (about 1 GB, into %APPDATA%\Godot).
# For a double-clickable installer around this exe, use tools\installer.ps1 instead.
param([string]$Version)
. "$PSScriptRoot\godot.ps1"

# Stamp the version the game reports onto the exe, so its file properties, the installer
# and the title screen all say the same number. Windows wants four numbers.
if (-not $Version) { $Version = Get-EbbVersion }
$quad = ($Version.Split(".") + @("0", "0", "0", "0"))[0..3] -join "."
$presets = Join-Path $ProjectRoot "export_presets.cfg"
$cfg = Get-Content $presets -Raw
$stamped = $cfg -replace 'application/file_version="[^"]*"', "application/file_version=`"$quad`"" `
                -replace 'application/product_version="[^"]*"', "application/product_version=`"$quad`""
if ($stamped -ne $cfg) {
    Set-Content -Path $presets -Value $stamped -NoNewline -Encoding utf8
    Write-Host "stamped export_presets.cfg with $quad"
}

$TemplateVersion = "4.7.2.stable"
$TemplateDir = Join-Path $env:APPDATA "Godot\export_templates\$TemplateVersion"
$Needed = Join-Path $TemplateDir "windows_release_x86_64.exe"

if (-not (Test-Path $Needed)) {
    $tpz = Join-Path $env:TEMP "godot_templates_4.7.2.tpz"
    if (-not (Test-Path $tpz) -or (Get-Item $tpz).Length -lt 100MB) {
        Write-Host "Downloading export templates..."
        curl.exe -L -o $tpz "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
        if ($LASTEXITCODE -ne 0) { throw "template download failed" }
    }
    $zip = "$tpz.zip"
    Copy-Item $tpz $zip -Force
    $tmp = Join-Path $env:TEMP "godot_templates_extract"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Write-Host "Extracting templates..."
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force $TemplateDir | Out-Null
    Copy-Item (Join-Path $tmp "templates\*") $TemplateDir -Recurse -Force
    Remove-Item $tmp -Recurse -Force
    Remove-Item $zip -Force
}

$dist = Join-Path $ProjectRoot "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$exe = Join-Path $dist "EBB.exe"
& $GodotExe --headless --path "$ProjectRoot" --import | Out-Null

# Build into an empty folder of its own, then move the result into place.
#
# Godot writes the exe, then rewrites it through a .tmp beside it to stamp the icon and the
# version in (application/modify_resources). The virus scanner grabs the 110 MB file as it
# lands, Godot's rename loses the race, and it still exits 0: sometimes the finished build
# is left in the .tmp, sometimes the rename only goes through a few seconds after Godot has
# gone. Exporting over the last build turned that into a stale exe that the installer then
# wrapped and handed out as an update, which is the one outcome worth failing over. A fresh
# folder every time means whatever ends up in it is this build and nothing else.
$stage = Join-Path $dist (".build-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
$stagedExe = Join-Path $stage "EBB.exe"
$stagedTmp = Join-Path $stage "EBB.tmp"
try {
    & $GodotExe --headless --path "$ProjectRoot" --export-release "Windows Desktop" `
        ("dist/" + (Split-Path $stage -Leaf) + "/EBB.exe")
    if ($LASTEXITCODE -ne 0) { throw "export failed ($LASTEXITCODE)" }

    # Give the scanner up to three minutes to let go, finishing the swap ourselves if Godot
    # could not. Poll rather than look once: the file can appear seconds after Godot exits.
    $deadline = (Get-Date).AddSeconds(180)
    while ($true) {
        if (Test-Path $stagedTmp) {
            try { Move-Item $stagedTmp $stagedExe -Force -ErrorAction Stop } catch {}
        }
        if (Test-Path $stagedExe) { break }
        if ((Get-Date) -ge $deadline) { throw "the export never produced an exe in $stage" }
        Start-Sleep -Milliseconds 500
    }
    $ver = (Get-Item $stagedExe).VersionInfo.FileVersion
    if ($ver -ne $quad) { throw "the exported exe says version $ver, expected $quad" }

    $deadline = (Get-Date).AddSeconds(180)
    while ($true) {
        try { Move-Item $stagedExe $exe -Force -ErrorAction Stop; break }
        catch {
            if ((Get-Date) -ge $deadline) { throw "could not replace dist\EBB.exe: $($_.Exception.Message)" }
            Start-Sleep -Milliseconds 500
        }
    }
} finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}
Get-ChildItem $dist -File | Format-Table Name, Length
