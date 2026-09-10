# Generates the PWA icon set from the Octopus source artwork.
#
# ⚠️ SUPERSEDED. `tools/generate_brand_assets.py` at the repo root now writes
# every icon in the ecosystem — this app's included — from the two master SVGs
# in `img/`. Use that; it is the one that stays in step with the brand. This
# script is kept because it is the only generator that runs with nothing but
# PowerShell, and it has been updated to the current plate so running it cannot
# quietly reintroduce the retired navy artwork.
#
# The source PNG has transparent corners (its background is a rounded rect),
# which is fine for standard Chrome icons but wrong for two cases:
#   * maskable icons  - the launcher crops to a circle/squircle, so the art
#                       must sit inside the inner 80% "safe zone" over a
#                       full-bleed background.
#   * apple-touch-icon - iOS composites transparency onto black and applies
#                       its own corner mask, so a transparent corner would come
#                       back BLACK against a white plate.
# Both therefore get an opaque backdrop matching the artwork's own plate.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\generate_icons.ps1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root '..\Octopus_Dashboard\OwnerDashboard\icon.png'
$iconsDir = Join-Path $root 'web\icons'
$webDir = Join-Path $root 'web'

if (-not (Test-Path $source)) { throw "Source icon not found: $source" }

# Plate gradient, quoted from img/icon.svg's plateGrad stops. Light now, not
# navy: the brand runs white-first and the mark is a flat blue on top of it.
$bgStart = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')
$bgEnd = [System.Drawing.ColorTranslator]::FromHtml('#E8F3F9')

$src = [System.Drawing.Image]::FromFile($source)

function New-Icon {
    param(
        [int]$Size,
        [string]$Path,
        [bool]$Opaque,
        [double]$Inset = 1.0   # fraction of the canvas the artwork occupies
    )

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($Opaque) {
        $rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect, $bgStart, $bgEnd, 45.0)
        $g.FillRectangle($brush, $rect)
        $brush.Dispose()
    }

    $art = [int]([math]::Round($Size * $Inset))
    $offset = [int]([math]::Round(($Size - $art) / 2.0))
    $g.DrawImage($src, $offset, $offset, $art, $art)

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  wrote $(Split-Path -Leaf $Path) (${Size}x${Size})"
}

Write-Host 'Generating PWA icons...'

# Standard Chrome/Android icons - transparency preserved.
New-Icon -Size 192 -Path (Join-Path $iconsDir 'Icon-192.png') -Opaque $false
New-Icon -Size 512 -Path (Join-Path $iconsDir 'Icon-512.png') -Opaque $false

# Maskable: full-bleed background, artwork inside the 80% safe zone.
New-Icon -Size 192 -Path (Join-Path $iconsDir 'Icon-maskable-192.png') -Opaque $true -Inset 0.76
New-Icon -Size 512 -Path (Join-Path $iconsDir 'Icon-maskable-512.png') -Opaque $true -Inset 0.76

# iOS home screen: opaque, near full-bleed (iOS applies its own corner mask).
New-Icon -Size 180 -Path (Join-Path $iconsDir 'apple-touch-icon-180.png') -Opaque $true -Inset 0.88
New-Icon -Size 167 -Path (Join-Path $iconsDir 'apple-touch-icon-167.png') -Opaque $true -Inset 0.88
New-Icon -Size 152 -Path (Join-Path $iconsDir 'apple-touch-icon-152.png') -Opaque $true -Inset 0.88

# Browser tab favicons.
New-Icon -Size 32 -Path (Join-Path $webDir 'favicon.png') -Opaque $false
New-Icon -Size 16 -Path (Join-Path $iconsDir 'favicon-16.png') -Opaque $false

$src.Dispose()
Write-Host 'Done.'
