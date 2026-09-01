<#
.SYNOPSIS
Interactive Release Manager for POS-APP
#>

$ErrorActionPreference = "Stop"

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "       POS-APP RELEASE MANAGER           " -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host " 1 " -ForegroundColor Yellow -NoNewline; Write-Host "- Commit & Push current work"
    Write-Host " 2 " -ForegroundColor Yellow -NoNewline; Write-Host "- Merge a branch into main"
    Write-Host " 3 " -ForegroundColor Yellow -NoNewline; Write-Host "- Deploy to OVH Test (Merge main -> test)"
    Write-Host " 4 " -ForegroundColor Yellow -NoNewline; Write-Host "- Trigger Build & Release (Tag version)"
    Write-Host " 5 " -ForegroundColor Yellow -NoNewline; Write-Host "- Database Migration Instructions"
    Write-Host " 0 " -ForegroundColor Yellow -NoNewline; Write-Host "- Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Step-Commit {
    $branch = git branch --show-current
    Write-Host "`nCurrent branch: $branch" -ForegroundColor Green
    $msg = Read-Host "Enter commit message (e.g., 'fix(pos): corrected barcode reader')"
    if ([string]::IsNullOrWhiteSpace($msg)) { Write-Host "Aborted." -ForegroundColor Red; return }
    
    git add .
    git commit -m "$msg"
    git push origin $branch
    Write-Host "`nWork pushed successfully!" -ForegroundColor Green
    Pause
}

function Step-MergeMain {
    $branch = Read-Host "Enter the branch name you want to merge into 'main'"
    if ([string]::IsNullOrWhiteSpace($branch)) { return }
    
    git checkout main
    git pull origin main
    git merge $branch
    git push origin main
    
    Write-Host "`nMerged $branch into main!" -ForegroundColor Green
    git log --oneline -3
    Pause
}

function Step-DeployTest {
    Write-Host "`nDeploying to OVH Test..." -ForegroundColor Cyan
    git checkout test
    git pull origin test
    git merge main
    git push origin test
    
    Write-Host "`nTriggered! Check GitHub Actions: Deploy Backend to OVH Test." -ForegroundColor Green
    Write-Host "URL: https://51-91-6-6.sslip.io/dashboard/" -ForegroundColor DarkGray
    Pause
}

function Step-Release {
    Write-Host "`nEnsuring tree is clean on main..." -ForegroundColor Cyan
    git checkout main
    git pull origin main
    
    if (git status --porcelain) {
        Write-Host "ERROR: Working directory is not clean. Commit your changes first." -ForegroundColor Red
        Pause
        return
    }

    $version = Read-Host "Enter new version number (e.g., 1.0.6)"
    if ([string]::IsNullOrWhiteSpace($version)) { return }

    Write-Host "`nRunning tools\release.ps1 for v$version..." -ForegroundColor Cyan
    .\tools\release.ps1 $version
    
    Write-Host "`nRelease triggered! Check GitHub Releases for the Windows and macOS installers." -ForegroundColor Green
    Pause
}

function Step-Database {
    Write-Host "`n⚠️ MANUAL DATABASE MIGRATION REQUIRED ⚠️" -ForegroundColor Red
    Write-Host "Run the following commands directly on the OVH Server via RDP:" -ForegroundColor White
    Write-Host "--------------------------------------------------------"
    Write-Host "cd C:\actions-runner\_work\POS-APP\POS-APP" -ForegroundColor Yellow
    Write-Host "git pull" -ForegroundColor Yellow
    Write-Host ".\tools\update-test-database.ps1 -WhatIf" -ForegroundColor Yellow
    Write-Host ".\tools\update-test-database.ps1" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    Pause
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' { Step-Commit }
        '2' { Step-MergeMain }
        '3' { Step-DeployTest }
        '4' { Step-Release }
        '5' { Step-Database }
        '0' { Write-Host "Goodbye!"; break }
        default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne '0')