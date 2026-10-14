# Puts EBB on GitHub as it should be: main pushed, the release tagged and published with its
# setup exe and notes, the repository's settings, its rules, and its security switches.
#
#   .\tools\github.ps1                     print what it would do, change nothing
#   .\tools\github.ps1 -Apply              do all of it
#   .\tools\github.ps1 -Apply -Release     only push, tag and publish the release (any later version too)
#   .\tools\github.ps1 -Apply -Settings    only the settings, topics, rules and security
#   .\tools\github.ps1 -Apply -FixOldRelease   once: the release tagged 1.0.0 holds 1.3.0; say so
#
# Needs the GitHub CLI signed in (`gh auth status`). The version is Game.VERSION; the release is
# tagged at the commit that set it, with dist\EBB-Setup-<version>.exe and docs\releases\<version>.md
# (its first line, "# ...", is the title). Rules come from .github\rulesets\*.json; the same files
# import by hand under Settings > Rules > Rulesets > Import a ruleset.
param(
    [switch]$Apply,
    [switch]$Release,
    [switch]$Settings,
    [switch]$FixOldRelease,
    [string]$Repo = "lakshgupta8/EBB",
    [string]$Version
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"
Set-Location $ProjectRoot
if (-not ($Release -or $Settings -or $FixOldRelease)) { $Release = $true; $Settings = $true; $FixOldRelease = $true }
if (-not $Version) { $Version = Get-EbbVersion }

function Step([string]$what, [scriptblock]$do) {
    if ($Apply) {
        Write-Host "-> $what" -ForegroundColor Cyan
        & $do
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "failed: $what (exit $LASTEXITCODE)" }
    } else {
        Write-Host "would: $what"
    }
}

function Write-Temp([string]$text) {
    $f = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($f, $text, (New-Object Text.UTF8Encoding $false))
    return $f
}

# A release's notes file: the title from its first line, the rest as the body.
function Read-Notes([string]$ver) {
    $path = Join-Path $ProjectRoot "docs\releases\$ver.md"
    if (-not (Test-Path $path)) { throw "no release notes at $path" }
    $lines = Get-Content $path -Encoding utf8
    if (-not $lines[0].StartsWith("# ")) { throw "$path must start with '# <title>'" }
    return @{ title = $lines[0].Substring(2).Trim(); body = Write-Temp ((($lines | Select-Object -Skip 1) -join "`n").Trim() + "`n") }
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "the GitHub CLI is not signed in: run 'gh auth login'" }
if (-not $Apply) { Write-Host "Dry run: nothing is changed. Add -Apply to do it.`n" -ForegroundColor Yellow }

if ($Release) {
    $setup = Join-Path $ProjectRoot "dist\EBB-Setup-$Version.exe"
    if (-not (Test-Path $setup)) { throw "$setup is not built: run .\tools\installer.ps1" }
    $exeVersion = (Get-Item (Join-Path $ProjectRoot "dist\EBB.exe")).VersionInfo.FileVersion
    if (-not $exeVersion.StartsWith($Version)) { throw "dist\EBB.exe is $exeVersion, not ${Version}: rebuild before releasing" }
    # The release is the commit that set the version, not whatever main has grown since.
    $commit = git log -1 --format=%H -S "const VERSION := `"$Version`"" -- src/core/game.gd
    if (-not $commit) { throw "no commit sets Game.VERSION to $Version" }
    $dirty = git status --porcelain
    if ($dirty) { Write-Host "note: uncommitted changes stay local:`n$($dirty -join "`n")" -ForegroundColor Yellow }
    $notes = Read-Notes $Version
    $hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
    if (-not (Get-Content (Join-Path $ProjectRoot "docs\releases\$Version.md") -Raw).Contains($hash)) {
        throw "docs\releases\$Version.md does not carry the setup's SHA-256 ($hash)"
    }
    Write-Host "release $Version at $($commit.Substring(0, 7)): $($notes.title)"
    Step "push main to origin" { git push origin main }
    if (-not (git tag --list $Version)) {
        Step "tag $Version at $($commit.Substring(0, 7))" { git tag -a $Version $commit -m "EBB $Version" }
    }
    Step "push the tag $Version" { git push origin "refs/tags/$Version" }
    gh release view $Version -R $Repo 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Step "replace the setup on release $Version and its notes" {
            gh release upload $Version $setup -R $Repo --clobber
            gh release edit $Version -R $Repo --title $notes.title --notes-file $notes.body --latest
        }
    } else {
        Step "publish release $Version with EBB-Setup-$Version.exe, marked latest" {
            gh release create $Version $setup -R $Repo --verify-tag --title $notes.title --notes-file $notes.body --latest
        }
    }
}

if ($FixOldRelease) {
    # Published 2026-10-03 as "EBB-release", tag 1.0.0: its exe is byte for byte the 1.3.0 setup.
    gh release view 1.0.0 -R $Repo 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $old = Read-Notes "1.3.0"
        Step "retitle the release tagged 1.0.0 as '$($old.title)' with notes saying what it holds" {
            gh release edit 1.0.0 -R $Repo --title $old.title --notes-file $old.body --latest=false
        }
        $asset = gh api "repos/$Repo/releases/tags/1.0.0" --jq '.assets[] | select(.name == "EBB-Setup-1.0.0.exe") | .id'
        if ($asset) {
            Step "rename its asset EBB-Setup-1.0.0.exe to EBB-Setup-1.3.0.exe" {
                gh api -X PATCH "repos/$Repo/releases/assets/$asset" -f name=EBB-Setup-1.3.0.exe | Out-Null
            }
        }
    } else {
        Write-Host "no release tagged 1.0.0: nothing to fix"
    }
}

if ($Settings) {
    $topics = "godot,godot4,gdscript,game,roguelite,roguelike,pixel-art,top-down,action-game,windows,procedural-generation"
    Step "description, homepage, topics; issues on, wiki and projects off; squash merges only, branches deleted after merge" {
        gh repo edit $Repo `
            --description "Keep the tide. A top-down pixel-art action roguelite for Windows, built in Godot 4." `
            --homepage "https://github.com/$Repo/releases/latest" `
            --add-topic $topics `
            --enable-issues --enable-wiki=false --enable-projects=false --enable-discussions=false `
            --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge
    }
    Step "secret scanning and push protection on" {
        $f = Write-Temp '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
        gh api -X PATCH "repos/$Repo" --input $f | Out-Null
    }
    Step "private vulnerability reporting on" { gh api -X PUT "repos/$Repo/private-vulnerability-reporting" | Out-Null }
    $have = @{}
    foreach ($r in (gh api "repos/$Repo/rulesets" | ConvertFrom-Json)) { $have[$r.name] = $r.id }
    foreach ($file in Get-ChildItem (Join-Path $ProjectRoot ".github\rulesets") -Filter *.json) {
        $name = (Get-Content $file.FullName -Raw | ConvertFrom-Json).name
        if ($have.ContainsKey($name)) {
            Step "update the ruleset '$name' from $($file.Name)" { gh api -X PUT "repos/$Repo/rulesets/$($have[$name])" --input $file.FullName | Out-Null }
        } else {
            Step "create the ruleset '$name' from $($file.Name)" { gh api -X POST "repos/$Repo/rulesets" --input $file.FullName | Out-Null }
        }
    }
    Write-Host "by hand: Settings > General > Social preview > upload .github\social-preview.png (GitHub has no API for it)"
}
