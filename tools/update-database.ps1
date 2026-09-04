<#
.SYNOPSIS
  Applies pending EF Core migrations to the production database. Run on the
  production server after every backend deploy.

.DESCRIPTION
  deploy-backend-prod.yml publishes the API but never touches the database, and
  Program.cs has no Database.Migrate() call. So the schema stays where it was
  while the code moves on, and the first endpoint that reads a new column answers
  500 instead of data.

  That is not hypothetical. After 20260820124336_AddSellByWeightAndBarcodeRules
  added Product.IsToWeigh, Product.UomId and the BarcodeRule table, every sync
  step that touches Product failed at once - products, productComments, stocks,
  stockControls, productTaxes, barcodes, barcodeRules, sessions - while taxes,
  customers, users and warehouses synced fine, because they never join Product.
  Redeploying could not fix it: the code was already correct, the database was
  not.

  The connection string is never typed into this script or stored beside it. It
  is read out of the web.config that the deploy workflow just wrote, so there is
  no secret here and no way to point at a stale database by copy-paste.

  NOTE: this file is deliberately pure ASCII, for the reason spelled out at the
  top of release.ps1 - Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI, and
  a UTF-8 dash becomes a parse error nowhere near the real line. Keep it ASCII.

.EXAMPLE
  ./tools/update-database.ps1
  ./tools/update-database.ps1 -WhatIf       # list what is pending, apply nothing
  ./tools/update-database.ps1 -ScriptOnly   # write the SQL for review instead
  ./tools/update-database.ps1 -RestartIis   # recycle the site afterwards
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The API project. Defaults to this repo's copy, since the script lives in
    # tools/ - pass it only when running the script from outside a checkout.
    [string]$ProjectPath,

    # Where the deploy workflow writes the environment variables, including the
    # connection string this script reads.
    [string]$WebConfig = 'C:\inetpub\wwwroot\pos-api\web.config',

    # The API has two DbContexts (App + Master). Only AppDbContext owns the
    # migrations in Back-End/Web-POS.Api/Migrations, and `dotnet ef` refuses to
    # guess when there is more than one.
    [string]$Context = 'AppDbContext',

    # Write an idempotent .sql file instead of touching the database, so the
    # change can be reviewed (or handed to a DBA) before it runs.
    [switch]$ScriptOnly,

    # Recycle IIS when the migration succeeds. Off by default: iisreset stops
    # every site on the box, which is rude if this one is not alone.
    [switch]$RestartIis
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ProjectPath) {
    $ProjectPath = Join-Path $repoRoot 'Back-End\Web-POS.Api'
}

# -- Preconditions ----------------------------------------------------------
# Each of these is a thing that has to be true before anything is changed, and
# each failure names its own fix. A migration run that dies halfway through is
# far more expensive than one that refuses to start.

if (-not (Test-Path (Join-Path $ProjectPath 'Web-POS.Api.csproj'))) {
    throw "No Web-POS.Api.csproj under '$ProjectPath'. Pass -ProjectPath with the folder that contains it."
}
if (-not (Test-Path $WebConfig)) {
    throw "web.config not found at '$WebConfig'. Is the API deployed on this machine? Pass -WebConfig if it lives elsewhere."
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "The dotnet CLI is not on PATH. Install the .NET SDK on this machine."
}

# -- 1. Read the connection string out of the deployed web.config -----------
[xml]$xml = Get-Content $WebConfig -Raw

# Matched in XPath, and read with GetAttribute, on purpose. PowerShell's XML
# adapter does NOT surface an attribute whose name collides with an intrinsic
# XmlElement member, and both 'name' and 'value' collide: $node.name returns the
# element name ('environmentVariable') for every node, so a Where-Object filter
# on $_.name silently matches nothing at all.
$node = $xml.SelectSingleNode("//environmentVariable[@name='ConnectionStrings__DefaultConnection']")
$connection = if ($node) { $node.GetAttribute('value') } else { $null }

if ([string]::IsNullOrWhiteSpace($connection)) {
    throw "web.config has no ConnectionStrings__DefaultConnection. The 'Inject production secrets into web.config' step of the deploy workflow did not run - redeploy before migrating."
}

# Show WHICH database is about to change, without ever printing the password.
# Applying migrations to the wrong catalog is the one mistake here that is not
# cheap to undo.
function Get-CsPart([string]$cs, [string[]]$keys) {
    foreach ($pair in $cs.Split(';')) {
        $kv = $pair.Split('=', 2)
        if ($kv.Count -eq 2 -and $keys -contains $kv[0].Trim()) { return $kv[1].Trim() }
    }
    return '(unknown)'
}
$server   = Get-CsPart $connection @('Server', 'Data Source')
$database = Get-CsPart $connection @('Database', 'Initial Catalog')

Write-Host ''
Write-Host "Project  : $ProjectPath"
Write-Host "Server   : $server"
Write-Host "Database : $database"

# Which commit this checkout is on. Migrations that are not in the working tree
# cannot be applied, and "I redeployed and it still 500s" is usually this.
if (Get-Command git -ErrorAction SilentlyContinue) {
    $branch = (git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null)
    $commit = (git -C $repoRoot rev-parse --short HEAD 2>$null)
    if ($branch) { Write-Host "Checkout : $branch @ $commit" }
}
Write-Host ''

# -- 2. Make sure the EF tool is available ----------------------------------
# Global tools land in this folder, which is not on PATH in a fresh shell.
$toolPath = Join-Path $env:USERPROFILE '.dotnet\tools'
if ((Test-Path $toolPath) -and ($env:PATH -notlike "*$toolPath*")) {
    $env:PATH = "$env:PATH;$toolPath"
}

# stderr goes to $null, never to 2>&1: merging a native command's stderr into the
# success stream raises a NativeCommandError, which $ErrorActionPreference='Stop'
# turns into a thrown exception - so probing for a MISSING tool would abort the
# script instead of installing it.
& dotnet ef --version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Installing the dotnet-ef tool...'
    & dotnet tool install --global dotnet-ef
    if ($LASTEXITCODE -ne 0) { throw 'dotnet tool install --global dotnet-ef failed.' }
    if ((Test-Path $toolPath) -and ($env:PATH -notlike "*$toolPath*")) {
        $env:PATH = "$env:PATH;$toolPath"
    }
}

# -- 3. Show what is pending BEFORE changing anything ------------------------
# `migrations list` marks each one Applied or Pending against the live database,
# so this is the answer to "is the schema actually behind?" - and with -WhatIf it
# is the whole point of running the script.
Write-Host 'Migrations (Pending = not yet in this database):' -ForegroundColor Cyan
& dotnet ef migrations list --project $ProjectPath --context $Context --connection $connection --no-color
if ($LASTEXITCODE -ne 0) { throw 'dotnet ef migrations list failed. The message above says why - most often the project does not build, or the database is unreachable.' }
Write-Host ''

# -- 4. Either write the SQL, or apply it -----------------------------------
if ($ScriptOnly) {
    $out = Join-Path $env:TEMP ("migrate-{0}-{1:yyyyMMdd-HHmmss}.sql" -f $database, (Get-Date))
    # Idempotent: every statement is guarded, so the file is safe to run against
    # a database that is already partly (or fully) up to date.
    & dotnet ef migrations script --idempotent --project $ProjectPath --context $Context --output $out
    if ($LASTEXITCODE -ne 0) { throw 'dotnet ef migrations script failed.' }
    Write-Host "SQL written to $out" -ForegroundColor Green
    Write-Host 'Review it, then run it against the database above in SSMS.'
    return
}

if (-not $PSCmdlet.ShouldProcess("$database on $server", 'apply pending EF migrations')) {
    Write-Host 'Nothing applied (-WhatIf).' -ForegroundColor Yellow
    return
}

& dotnet ef database update --project $ProjectPath --context $Context --connection $connection
if ($LASTEXITCODE -ne 0) { throw 'dotnet ef database update FAILED. The database may be partly migrated - read the error above before retrying.' }

# -- 5. Recycle, so nothing serves from a model cached before the change -----
if ($RestartIis) {
    Write-Host ''
    Write-Host 'Restarting IIS...'
    iisreset
}

Write-Host ''
Write-Host "Database '$database' is up to date." -ForegroundColor Green
Write-Host 'Sync from a terminal to confirm: products, stocks and barcodes should all come back clean.' -ForegroundColor Green
