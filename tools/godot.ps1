# Resolves the Godot executable. Dot-source this: . "$PSScriptRoot\godot.ps1"
$script:GodotExe = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if (-not (Test-Path $script:GodotExe)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $script:GodotExe = $cmd.Source } else { throw "Godot not found. Install with: winget install GodotEngine.GodotEngine" }
}
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
