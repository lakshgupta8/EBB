# Resolves the Godot executable. Dot-source this: . "$PSScriptRoot\godot.ps1"
$script:GodotExe = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if (-not (Test-Path $script:GodotExe)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $script:GodotExe = $cmd.Source } else { throw "Godot not found. Install with: winget install GodotEngine.GodotEngine" }
}
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

# The version the game reports, and the one the exe and the installer are stamped with.
function Get-EbbVersion {
    $gd = Get-Content (Join-Path $script:ProjectRoot "src\core\game.gd") -Raw
    $m = [regex]::Match($gd, 'const VERSION\s*:=\s*"([0-9]+(?:\.[0-9]+)*)"')
    if (-not $m.Success) { throw "could not read Game.VERSION from src\core\game.gd" }
    return $m.Groups[1].Value
}
