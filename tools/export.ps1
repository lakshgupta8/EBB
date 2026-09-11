# Build the Windows executable into dist\EBB.exe.  Usage: .\tools\export.ps1
# Fetches the 4.7.2 export templates the first time (about 1 GB, into %APPDATA%\Godot).
. "$PSScriptRoot\godot.ps1"
$Version = "4.7.2.stable"
$TemplateDir = Join-Path $env:APPDATA "Godot\export_templates\$Version"
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
& $GodotExe --headless --path "$ProjectRoot" --import | Out-Null
& $GodotExe --headless --path "$ProjectRoot" --export-release "Windows Desktop" "dist/EBB.exe"
if ($LASTEXITCODE -ne 0) { throw "export failed ($LASTEXITCODE)" }
Get-ChildItem $dist | Format-Table Name, Length
