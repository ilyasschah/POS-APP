<#
.SYNOPSIS
  Interactive Release Manager for POS-APP.

.DESCRIPTION
  A menu over the steps in RELEASE_RUNBOOK.md. It does not replace that
  document - read it once, then use this to avoid typing the sequences wrong.

  What this repo ships (six things, three release paths):

    Back-End/               -> IIS at api.octopus-pos.com   (push to prod)
    (admin portal)          -> api.octopus-pos.com/admin    (same deploy)
    octopus_dashboard_web/  -> api.octopus-pos.com/dashboard/ (push to prod)
    website/                -> octopus-pos.com              (push to prod)
    Front-End/              -> Windows .exe + macOS .dmg    (tag  v*)
    kitchen_display/        -> Windows .exe + Android .apk  (tag  kds-v*)

    Octopus_Dashboard/      -> native iOS app, NO CI, built from Xcode.

  Every server deploy is PATH-FILTERED. Pushing to prod with no changes under
  Back-End/, octopus_dashboard_web/ or website/ runs nothing at all, silently.
  Option 3 shows you which workflows a push will actually trigger before it
  pushes.

  NOTE: this file is deliberately pure ASCII, for the reason spelled out at the
  top of tools/release.ps1 - Windows PowerShell 5.1 reads a BOM-less .ps1 using
  the system ANSI codepage, so a UTF-8 dash or emoji arrives as mojibake, one
  byte of which can be a smart quote that terminates a string and produces a
  parse error nowhere near the real line. Keep it ASCII.
#>

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot

# --- helpers ---------------------------------------------------------------

function Confirm-Action([string]$Prompt) {
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -eq 'y' -or $answer -eq 'Y')
}

function Assert-CleanTree {
    if (git status --porcelain) {
        Write-Host "ERROR: Working directory is not clean. Commit or stash first." -ForegroundColor Red
        git status --short
        return $false
    }
    return $true
}

# Windows PowerShell 5.1's Invoke-WebRequest cannot report a 3xx: with
# -MaximumRedirection 0 it throws an exception carrying no .Response, so the
# status code is unreachable. HttpWebRequest returns the 3xx as a normal
# response instead. Same approach the deploy workflow uses.
function Get-HttpStatus([string]$Url) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.AllowAutoRedirect = $false
    $req.Timeout = 15000
    $req.Method = "GET"
    try {
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return $code
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            $_.Exception.Response.Close()
            return $code
        }
        return 0    # DNS failure, TLS failure, connection refused
    }
}

function Write-Check([string]$Label, [int]$Actual, [int]$Expected) {
    if ($Actual -eq $Expected) {
        Write-Host ("  OK    {0,-46} {1}" -f $Label, $Actual) -ForegroundColor Green
    } elseif ($Actual -eq 0) {
        Write-Host ("  DOWN  {0,-46} unreachable" -f $Label) -ForegroundColor Red
    } else {
        Write-Host ("  FAIL  {0,-46} {1} (expected {2})" -f $Label, $Actual, $Expected) -ForegroundColor Red
    }
}

function Get-PubspecVersion([string]$RelativePath) {
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $path)) { return $null }
    $line = (Get-Content $path | Select-String '^version:').Line
    if (-not $line) { return $null }
    return $line.Split(':')[1].Trim()
}

# --- menu ------------------------------------------------------------------

function Show-Menu {
    Clear-Host
    $pos = Get-PubspecVersion 'Front-End/pubspec.yaml'
    $kds = Get-PubspecVersion 'kitchen_display/pubspec.yaml'
    $branch = git branch --show-current

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "        POS-APP RELEASE MANAGER              " -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " branch: " -NoNewline -ForegroundColor DarkGray
    Write-Host $branch -NoNewline -ForegroundColor White
    Write-Host "   POS: " -NoNewline -ForegroundColor DarkGray
    Write-Host $pos -NoNewline -ForegroundColor White
    Write-Host "   KDS: " -NoNewline -ForegroundColor DarkGray
    Write-Host $kds -ForegroundColor White
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    Write-Host " GIT" -ForegroundColor DarkGray
    Write-Host " 1 " -ForegroundColor Yellow -NoNewline; Write-Host "- Commit and push current work"
    Write-Host " 2 " -ForegroundColor Yellow -NoNewline; Write-Host "- Merge a branch into main"
    Write-Host ""
    Write-Host " SERVERS  (api + dashboard + website)" -ForegroundColor DarkGray
    Write-Host " 3 " -ForegroundColor Yellow -NoNewline; Write-Host "- Deploy to production (merge main -> prod)"
    Write-Host " 4 " -ForegroundColor Yellow -NoNewline; Write-Host "- Database migration instructions (run on server)"
    Write-Host " 5 " -ForegroundColor Yellow -NoNewline; Write-Host "- Production health check"
    Write-Host ""
    Write-Host " INSTALLERS" -ForegroundColor DarkGray
    Write-Host " 6 " -ForegroundColor Yellow -NoNewline; Write-Host "- Release POS app     (tag v*)      Windows + macOS"
    Write-Host " 7 " -ForegroundColor Yellow -NoNewline; Write-Host "- Release Kitchen Display (tag kds-v*)  Win + Android"
    Write-Host ""
    Write-Host " 8 " -ForegroundColor Yellow -NoNewline; Write-Host "- Show versions and recent tags"
    Write-Host " 0 " -ForegroundColor Yellow -NoNewline; Write-Host "- Exit"
    Write-Host "=============================================" -ForegroundColor Cyan
}

# --- 1. commit -------------------------------------------------------------

function Step-Commit {
    $branch = git branch --show-current
    Write-Host "`nCurrent branch: $branch" -ForegroundColor Green

    if (-not (git status --porcelain)) {
        Write-Host "Nothing to commit - the tree is clean." -ForegroundColor DarkGray
        Pause; return
    }

    git status --short
    Write-Host ""

    if ($branch -eq 'prod') {
        Write-Host "WARNING: you are on 'prod'. Committing here deploys straight to" -ForegroundColor Red
        Write-Host "production, bypassing main. Do this only for a hotfix." -ForegroundColor Red
        if (-not (Confirm-Action "Continue anyway?")) { return }
    }

    $msg = Read-Host "Commit message (e.g. 'fix(pos): corrected barcode reader')"
    if ([string]::IsNullOrWhiteSpace($msg)) { Write-Host "Aborted." -ForegroundColor Red; return }

    git add .
    git commit -m "$msg"
    git push origin $branch

    Write-Host "`nPushed to origin/$branch." -ForegroundColor Green
    Pause
}

# --- 2. merge into main ----------------------------------------------------

function Step-MergeMain {
    $branch = Read-Host "Branch to merge into 'main'"
    if ([string]::IsNullOrWhiteSpace($branch)) { return }

    if (-not (Assert-CleanTree)) { Pause; return }

    git checkout main
    git pull origin main
    git merge $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nMerge did not complete. Resolve the conflicts, then push by hand." -ForegroundColor Red
        Pause; return
    }
    git push origin main

    Write-Host "`nMerged $branch into main. Nothing has deployed yet - that is option 3." -ForegroundColor Green
    git log --oneline -3
    Pause
}

# --- 3. deploy to production ----------------------------------------------

function Step-DeployProd {
    Write-Host "`nChecking what a prod push would actually trigger..." -ForegroundColor Cyan
    git fetch origin --quiet

    $changed = git diff --name-only origin/prod..origin/main
    if (-not $changed) {
        Write-Host "origin/prod is already level with origin/main. Nothing to deploy." -ForegroundColor DarkGray
        Pause; return
    }

    # These prefixes are the path filters in .github/workflows/deploy-*.yml.
    # They are case-sensitive on GitHub's side (that bug cost the dashboard
    # workflow months of never running), so match them exactly.
    $backend   = $changed | Where-Object { $_ -like 'Back-End/*' }
    $dashboard = $changed | Where-Object { $_ -like 'octopus_dashboard_web/*' }
    $site      = $changed | Where-Object { $_ -like 'website/*' }
    $migrations = $changed | Where-Object { $_ -like 'Back-End/Web-POS.Api/Migrations/*' }

    Write-Host "`nWorkflows that will run:" -ForegroundColor White
    if ($backend)   { Write-Host "  * Deploy Backend to Production   ($($backend.Count) files)" -ForegroundColor Green }
    if ($dashboard) { Write-Host "  * Deploy Dashboard to Production ($($dashboard.Count) files)" -ForegroundColor Green }
    if ($site)      { Write-Host "  * Deploy Website to Production   ($($site.Count) files)" -ForegroundColor Green }

    if (-not ($backend -or $dashboard -or $site)) {
        Write-Host "  (none)" -ForegroundColor Yellow
        Write-Host "`nThe commits touch no deployable path, so pushing to prod will run" -ForegroundColor Yellow
        Write-Host "nothing at all. That is normal for a Front-End- or KDS-only change:" -ForegroundColor Yellow
        Write-Host "those ship as installers (options 6 and 7), not as a deploy." -ForegroundColor Yellow
    }

    if ($migrations) {
        Write-Host "`n*** MIGRATIONS CHANGED ***" -ForegroundColor Red
        $migrations | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        Write-Host "The deploy will NOT apply these. /health/ready returns 503 and the" -ForegroundColor Red
        Write-Host "workflow fails until you run option 4 on the server." -ForegroundColor Red
    }

    Write-Host "`nThis is PRODUCTION. Real customers see the result." -ForegroundColor Yellow
    if (-not (Confirm-Action "Merge main -> prod and push?")) { Write-Host "Aborted." ; Pause; return }

    if (-not (Assert-CleanTree)) { Pause; return }

    git checkout prod
    git pull origin prod
    git merge main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nMerge did not complete. Resolve the conflicts, then push by hand." -ForegroundColor Red
        Pause; return
    }
    git push origin prod

    Write-Host "`nPushed. Watch GitHub Actions:" -ForegroundColor Green
    Write-Host "  https://github.com/ilyasschah/POS-APP/actions" -ForegroundColor DarkGray
    Write-Host "The deploy runs on the self-hosted runner ON the OVH box. If the job" -ForegroundColor DarkGray
    Write-Host "queues forever, the runner is offline - check the server." -ForegroundColor DarkGray
    if ($migrations) {
        Write-Host "`nDo not forget option 4 (database), or the deploy will fail its" -ForegroundColor Yellow
        Write-Host "health check and the API will answer 500s." -ForegroundColor Yellow
    }
    Pause
}

# --- 4. database -----------------------------------------------------------

function Step-Database {
    Write-Host "`n*** MANUAL DATABASE MIGRATION - RUNS ON THE SERVER ***" -ForegroundColor Red
    Write-Host ""
    Write-Host "The deploy publishes the API and never touches the schema. It cannot" -ForegroundColor White
    Write-Host "run from this PC either: the script reads the connection string out of" -ForegroundColor White
    Write-Host "the deployed web.config, which only exists on the box." -ForegroundColor White
    Write-Host ""
    Write-Host "RDP into the OVH production server and run:" -ForegroundColor White
    Write-Host "------------------------------------------------------------"
    Write-Host "cd C:\actions-runner\_work\POS-APP\POS-APP" -ForegroundColor Yellow
    Write-Host "git pull" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ".\tools\update-database.ps1 -WhatIf      # list pending, change nothing" -ForegroundColor Yellow
    Write-Host ".\tools\update-database.ps1              # apply them" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ".\tools\update-database.ps1 -ScriptOnly  # write the SQL to review first" -ForegroundColor DarkGray
    Write-Host ".\tools\update-database.ps1 -RestartIis  # recycle the site afterwards" -ForegroundColor DarkGray
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "Then confirm: https://api.octopus-pos.com/health/ready returns 200." -ForegroundColor White
    Write-Host "There is no automatic rollback. -ScriptOnly is how you get one." -ForegroundColor DarkGray
    Pause
}

# --- 5. health check -------------------------------------------------------

function Step-Health {
    Write-Host "`nProbing production..." -ForegroundColor Cyan
    Write-Host ""

    Write-Check "api.octopus-pos.com/health/ready"      (Get-HttpStatus "https://api.octopus-pos.com/health/ready")      200
    Write-Check "api.octopus-pos.com/admin/login"       (Get-HttpStatus "https://api.octopus-pos.com/admin/login")       200
    Write-Check "admin/companies (must redirect: 302)"  (Get-HttpStatus "https://api.octopus-pos.com/admin/companies")   302
    Write-Check "api.octopus-pos.com/dashboard/"        (Get-HttpStatus "https://api.octopus-pos.com/dashboard/")        200
    Write-Check "octopus-pos.com"                       (Get-HttpStatus "https://octopus-pos.com/")                     200

    # Swagger must NOT answer in Production. If it does, ASPNETCORE_ENVIRONMENT
    # is not set to Production and this deploy is misconfigured.
    $swagger = Get-HttpStatus "https://api.octopus-pos.com/swagger"
    if ($swagger -eq 200) {
        Write-Host ("  WARN  {0,-46} 200 - should be disabled!" -f "swagger is exposed") -ForegroundColor Red
        Write-Host "        ASPNETCORE_ENVIRONMENT is not 'Production'." -ForegroundColor Red
    } else {
        Write-Host ("  OK    {0,-46} {1}" -f "swagger closed in production", $swagger) -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "503 on /health/ready = schema behind the code -> option 4." -ForegroundColor DarkGray
    Write-Host "302 on /admin/login  = the login page fell behind its own login." -ForegroundColor DarkGray
    Write-Host "200 on admin/companies while signed out = SECURITY problem, fix now." -ForegroundColor DarkGray
    Pause
}

# --- 6. POS release --------------------------------------------------------

function Step-ReleasePos {
    Write-Host "`nPOS app release: one tag builds BOTH the Windows installer and the" -ForegroundColor Cyan
    Write-Host "macOS DMG. Cut it from main." -ForegroundColor Cyan

    git checkout main
    git pull origin main
    if (-not (Assert-CleanTree)) { Pause; return }

    $current = Get-PubspecVersion 'Front-End/pubspec.yaml'
    Write-Host "`nFront-End/pubspec.yaml is currently: $current" -ForegroundColor White

    $version = Read-Host "New version (major.minor.patch, e.g. 1.0.13)"
    if ([string]::IsNullOrWhiteSpace($version)) { return }

    Write-Host "`nDry run first:" -ForegroundColor Cyan
    & "$RepoRoot\tools\release.ps1" $version -WhatIf

    if (-not (Confirm-Action "`nBump, commit, tag and push v$version?")) { Write-Host "Aborted."; Pause; return }

    & "$RepoRoot\tools\release.ps1" $version

    Write-Host "`nTagged. Two workflows are now running:" -ForegroundColor Green
    Write-Host "  Release Windows Installer -> Octopus_POS_Setup_v$version.exe" -ForegroundColor DarkGray
    Write-Host "  Release macOS DMG         -> Octopus_POS_v$version.dmg" -ForegroundColor DarkGray
    Write-Host "Both attach to the same GitHub Release. Check that BOTH arrive." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Reminder: the DMG is ad-hoc signed, not notarized. First launch on a" -ForegroundColor Yellow
    Write-Host "customer Mac needs right-click -> Open, or macOS calls it damaged." -ForegroundColor Yellow
    Pause
}

# --- 7. KDS release --------------------------------------------------------

function Step-ReleaseKds {
    Write-Host "`nKitchen Display release: builds the Windows installer and the Android" -ForegroundColor Cyan
    Write-Host "APK. Separate app, separate version, separate tag prefix." -ForegroundColor Cyan
    Write-Host "The prefix is 'kds-v'. A bare 'v' tag would fire the POS pipeline and" -ForegroundColor Yellow
    Write-Host "fail it, because that workflow checks the tag against Front-End." -ForegroundColor Yellow

    git checkout main
    git pull origin main
    if (-not (Assert-CleanTree)) { Pause; return }

    $pubspec = Join-Path $RepoRoot 'kitchen_display/pubspec.yaml'
    $current = Get-PubspecVersion 'kitchen_display/pubspec.yaml'
    Write-Host "`nkitchen_display/pubspec.yaml is currently: $current" -ForegroundColor White
    Write-Host "POS is at: $(Get-PubspecVersion 'Front-End/pubspec.yaml')  (keep these in step)" -ForegroundColor DarkGray

    $version = Read-Host "New KDS version (major.minor.patch, e.g. 1.0.13)"
    if ([string]::IsNullOrWhiteSpace($version)) { return }
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        Write-Host "Inno Setup rejects anything but major.minor.patch. Aborted." -ForegroundColor Red
        Pause; return
    }

    $tag = "kds-v$version"
    git fetch origin --tags --quiet
    if (git tag -l $tag) {
        Write-Host "Tag $tag already exists. Delete it first:" -ForegroundColor Red
        Write-Host "  git tag -d $tag ; git push --delete origin $tag" -ForegroundColor DarkGray
        Pause; return
    }

    # The build number must only ever go up: Android derives versionCode from it.
    $build = 0
    if ($current -match '\+(\d+)$') { $build = [int]$Matches[1] }
    $newValue = "$version+$($build + 1)"

    if ($current -eq $newValue) {
        Write-Host "pubspec is already $newValue - nothing to do." -ForegroundColor Red
        Pause; return
    }

    Write-Host "`npubspec : $current  ->  $newValue"
    Write-Host "tag     : $tag"
    if (-not (Confirm-Action "`nBump, commit, tag and push?")) { Write-Host "Aborted."; Pause; return }

    # Same order as tools/release.ps1: version, commit, THEN tag - so the tag
    # can never point at a commit still carrying the old version.
    $lines = Get-Content $pubspec
    $updated = $lines -replace '^version:.*', "version: $newValue"
    Set-Content -Path $pubspec -Value $updated -Encoding utf8

    git add -- 'kitchen_display/pubspec.yaml'
    git commit -m "chore(kds): release $version"
    git push origin main
    git tag $tag
    git push origin $tag

    Write-Host "`nTagged $tag. Watch 'Release Kitchen Display':" -ForegroundColor Green
    Write-Host "  Octopus_KDS_Setup_v$version.exe   (till / kitchen PC)" -ForegroundColor DarkGray
    Write-Host "  Octopus_KDS_v$version.apk         (sideload onto the tablet)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "The KDS never calls the backend - the POS pushes to it over the LAN on" -ForegroundColor DarkGray
    Write-Host "port 9090. If the push payload changed, release the POS alongside it." -ForegroundColor DarkGray
    Pause
}

# --- 8. versions -----------------------------------------------------------

function Step-Versions {
    Write-Host "`nVersions in the working tree" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    Write-Host ("  POS app       Front-End/            {0}" -f (Get-PubspecVersion 'Front-End/pubspec.yaml'))
    Write-Host ("  Kitchen disp. kitchen_display/      {0}" -f (Get-PubspecVersion 'kitchen_display/pubspec.yaml'))
    Write-Host ("  Dashboard web octopus_dashboard_web/ {0}" -f (Get-PubspecVersion 'octopus_dashboard_web/pubspec.yaml'))
    Write-Host "  Backend       Back-End/             (unversioned - deploys from prod)"
    Write-Host "  Website       website/              (unversioned - deploys from prod)"
    Write-Host "  iOS dashboard Octopus_Dashboard/    (no CI - Xcode by hand)"

    Write-Host "`nMost recent tags" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    git tag --sort=-creatordate | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" }

    Write-Host "`nBranch state" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    git fetch origin --quiet
    $ahead = (git rev-list --count origin/prod..origin/main)
    if ($ahead -eq '0') {
        Write-Host "  origin/main and origin/prod are level - production is current." -ForegroundColor Green
    } else {
        Write-Host "  origin/main is $ahead commit(s) ahead of origin/prod - not deployed." -ForegroundColor Yellow
    }
    Pause
}

# --- main loop -------------------------------------------------------------

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        '1' { Step-Commit }
        '2' { Step-MergeMain }
        '3' { Step-DeployProd }
        '4' { Step-Database }
        '5' { Step-Health }
        '6' { Step-ReleasePos }
        '7' { Step-ReleaseKds }
        '8' { Step-Versions }
        '0' { Write-Host "Goodbye!" }
        default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne '0')
