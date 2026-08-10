# Rebuilds appsettings.Local.json from the user-level environment variables.
#
# Why this exists: the folder was deleted once and every git-ignored file in it
# went too. The env vars survived, because `setx` writes to the registry rather
# than to the project — so the whole file can be reconstructed from them without
# anyone having to remember a connection string.
#
#   powershell -NoProfile -File restore-local-settings.ps1
#
# Safe to re-run. Refuses to overwrite unless -Force, and never prints a secret.
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'

$dbUser = [Environment]::GetEnvironmentVariable('WEBPOS_DB_USER', 'User')
$dbPass = [Environment]::GetEnvironmentVariable('WEBPOS_DB_PASSWORD', 'User')
if (-not $dbUser -or -not $dbPass) {
    throw "WEBPOS_DB_USER / WEBPOS_DB_PASSWORD are not set for this user. " +
          "Set them with setx, open a NEW shell, then re-run. See SECRETS.local.txt."
}

$path = Join-Path $PSScriptRoot 'appsettings.Local.json'
if ((Test-Path $path) -and -not $Force) {
    "$path already exists - pass -Force to overwrite."
    return
}

# `Data Source=localhost`, never the LAN IP: SQL Server is on this machine, so
# localhost goes over SHARED MEMORY. The LAN IP crosses the Ethernet NIC on a box
# full of virtual adapters and causes intermittent Win32Exception 258 pre-login
# failures that look exactly like code bugs. See SECRETS.local.txt.
$tmpl = 'Data Source=localhost;Initial Catalog={0};Persist Security Info=True;' +
        'User ID={1};Password={2};Multiple Active Result Sets=False;' +
        'Trust Server Certificate=True;Connect Timeout=30'

$cfg = [ordered]@{
    '_note' = 'MACHINE-LOCAL ONLY. Git-ignored and excluded from publish output. ' +
              'Put your own connection strings and any local secrets here. On a server, ' +
              'supply these via environment variables instead ' +
              '(ConnectionStrings__DefaultConnection, ConnectionStrings__MasterConnection, ' +
              'Jwt__Secret, AdminPortal__AccessKey).'
    'ConnectionStrings' = [ordered]@{
        'DefaultConnection' = ($tmpl -f 'web-pos', $dbUser, $dbPass)
        'MasterConnection'  = ($tmpl -f 'web-pos-master', $dbUser, $dbPass)
    }
    'Cors' = [ordered]@{
        'AllowedOrigins' = @(
            'http://100.114.12.38:8081',
            'http://localhost:8081',
            'http://127.0.0.1:8081'
        )
    }
}

$cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding utf8
"Wrote $path"

# Prove it, rather than assuming. A reconstructed connection string is worth
# nothing until it has actually opened.
$cfgBack = Get-Content $path -Raw | ConvertFrom-Json
foreach ($name in 'DefaultConnection', 'MasterConnection') {
    # PS 5.1 ships the .NET Framework provider, which rejects the spaced spellings
    # of these two keywords. Dropped for the check only; neither affects connectivity.
    $cs = ($cfgBack.ConnectionStrings.$name -split ';' | Where-Object {
        $_ -notmatch 'Multiple Active Result Sets' -and $_ -notmatch 'Trust Server Certificate'
    }) -join ';'
    $conn = New-Object System.Data.SqlClient.SqlConnection $cs
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = 'SELECT DB_NAME() AS db, (SELECT net_transport FROM sys.dm_exec_connections WHERE session_id=@@SPID) AS transport'
        $r = $cmd.ExecuteReader(); $null = $r.Read()
        "  {0,-18} OK  db={1,-16} transport={2}" -f $name, $r['db'], $r['transport']
        $r.Close()
    } catch {
        "  {0,-18} FAILED: {1}" -f $name, $_.Exception.Message
    } finally { $conn.Close() }
}
"Transport must read 'Shared memory'. If it says TCP, the Data Source is wrong."
