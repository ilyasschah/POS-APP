<#
.SYNOPSIS
  Cuts a release: updates pubspec, commits, tags and pushes - in that order.

.DESCRIPTION
  The release workflow refuses to build when the git tag disagrees with
  `version:` in Front-End/pubspec.yaml. That guard exists for a good reason (the
  in-app updater compares versions, so a build labelled with a number it does not
  contain is worse than no build), but the manual sequence is easy to get wrong,
  and has been, twice:

    * the tag was created BEFORE the pubspec change was committed, so it pointed
      at the previous commit which still carried the old version;
    * the pubspec was changed but the tag name was typed from memory.

  This script makes the two impossible to desync: it writes the version, commits
  it, and only then creates the tag on that exact commit.

  NOTE: this file is deliberately pure ASCII. Windows PowerShell 5.1 reads a .ps1
  without a byte-order mark using the system ANSI codepage, so a UTF-8 em dash
  arrives as three CP1252 characters - one of which is a smart quote that
  terminates the enclosing string and produces a parse error nowhere near the
  real line. Keep it ASCII.

.EXAMPLE
  ./tools/release.ps1 1.0.4
  ./tools/release.ps1 1.0.4 -WhatIf     # show what would happen, change nothing
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The release version, plain major.minor.patch. Inno's VersionInfoVersion
    # rejects anything else, so pre-release suffixes are refused here rather than
    # five minutes into the build.
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$pubspec  = Join-Path $repoRoot 'Front-End/pubspec.yaml'
$tag      = "v$Version"

if (-not (Test-Path $pubspec)) { throw "pubspec.yaml not found at $pubspec" }

Push-Location $repoRoot
try {
    # -- Refuse to release from a messy tree ---------------------------------
    # A dirty tree means the tag would capture work you have not reviewed.
    $dirty = git status --porcelain
    if ($dirty) {
        throw "Working tree is not clean. Commit or stash first:`n$dirty"
    }

    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    git fetch origin --tags --quiet

    if (git tag -l $tag) {
        throw "Tag $tag already exists. Remove it first:  git tag -d $tag ; git push --delete origin $tag"
    }

    # -- Work out the new version line ---------------------------------------
    $lines   = Get-Content $pubspec
    $current = ($lines | Select-String '^version:').Line
    if (-not $current) { throw "No 'version:' line in pubspec.yaml" }

    $currentValue = $current.Split(':')[1].Trim()          # e.g. 1.0.3+5
    $currentBuild = 0
    if ($currentValue -match '\+(\d+)$') { $currentBuild = [int]$Matches[1] }

    # The build number must only ever go UP: Android derives versionCode from it
    # and the Play Store rejects a decrease.
    $newBuild = $currentBuild + 1
    $newValue = "$Version+$newBuild"

    if ($currentValue -eq $newValue) {
        throw "pubspec is already $newValue - nothing to do."
    }

    Write-Host "Branch  : $branch"
    Write-Host "pubspec : $currentValue  ->  $newValue"
    Write-Host "Tag     : $tag"

    if (-not $PSCmdlet.ShouldProcess($branch, "release $newValue as $tag")) { return }

    # -- 1. version, 2. commit, 3. tag. The order is the whole point. ---------
    $updated = $lines -replace '^version:.*', "version: $newValue"
    Set-Content -Path $pubspec -Value $updated -Encoding utf8

    git add -- 'Front-End/pubspec.yaml'
    git commit -m "chore: release $Version"
    git push origin $branch

    # Created AFTER the commit, so it can only ever point at a tree whose pubspec
    # already says $Version. This is the step that used to go wrong.
    git tag $tag
    git push origin $tag

    Write-Host ""
    Write-Host "Released $tag. Watch the 'Release Windows Installer' workflow;" -ForegroundColor Green
    Write-Host "the installer appears on the GitHub Releases page when it finishes." -ForegroundColor Green
}
finally {
    Pop-Location
}
