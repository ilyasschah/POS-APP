# Production Server Setup — Octopus POS

Live state of the production cutover, written so a session with **no prior context**
can pick it up. Started 2026-09-03, Step 3 completed 2026-09-03.

> **Resume point: Step 7.3 (add the four repository secrets), then 7.7 (push
> `prod`).** Everything else is done and verified: the site is live on HTTPS,
> both databases exist and are permission-tested, Flutter and the Actions runner
> are installed, and the API has been booted end-to-end against the real
> databases with `/health/ready` green and `/admin` working.

---

## 0 · The facts

| | |
|---|---|
| **Domain** | `octopus-pos.com` (Namecheap, nameservers = **Namecheap PremiumDNS**) |
| **VPS** | OVH VPS-2 2027 · `51.255.38.247` · Dunkirk FR · 4 vCore · 7.8 GB RAM · 74.7 GB disk |
| **OS** | Windows Server 2022 Standard, build 10.0.20348, locale `en-US`, PowerShell 5.1 |
| **Server Tailscale IP** | `100.90.238.48` |
| **Dev machine Tailscale IP** | `100.114.12.38` |
| **Repo** | https://github.com/ilyasschah/POS-APP — ⚠️ **PUBLIC** |

### Access

RDP is restricted to `100.64.0.0/10` (the Tailscale CGNAT range) — **the public
port 3389 is closed and this was verified externally.** Reach the box at
`100.90.238.48`, not at its public IP.

Locked out? The **OVH KVM console** in the OVH Manager is out-of-band and
unaffected by any firewall or Tailscale state.

Tailscale on the server runs `--unattended` and has **key expiry disabled** — both
are required, or the box silently leaves the tailnet (on reboot, or after 180
days) while RDP is restricted to that tailnet.

---

## 1 · Target architecture

```
octopus-pos.com  ─┐
www.…            ─┴─→ IIS "octopus-site" → C:\inetpub\wwwroot\octopus-site   Next.js static export
api.…            ───→ IIS "pos-api"      → C:\inetpub\wwwroot\pos-api        ASP.NET Core via ANCM
                                          └─ /dashboard (IIS application)
                                             → C:\inetpub\wwwroot\dashboard  Flutter web
```

One win-acme certificate covers all three hostnames. Deploys come from the
**`prod`** branch via a self-hosted runner labelled `octopus-prod`.

### DNS — done and verified

| Type | Host | Value |
|---|---|---|
| A | `@` | `51.255.38.247` |
| A | `api` | `51.255.38.247` |
| CNAME | `www` | `octopus-pos.com.` |
| CAA | `@` | `0 issue "letsencrypt.org"` |
| TXT | `@` | `v=spf1 -all` |
| TXT | `_dmarc` | `v=DMARC1; p=reject; rua=mailto:ilyasschah18@gmail.com` |

The API sends no email (SMTP was retired 2026-09-03), so SPF/DMARC exist purely
to stop the domain being spoofed. Adding mailboxes later means relaxing both.

---

## 2 · Software state

**Present:** IIS · **URL Rewrite 2.1** (`7.2.1993`) · .NET SDK 10.0.400 ·
ASP.NET Core runtime 10.0.11 · Node v24.20.0 · Git 2.55 · SQL Server 2025
**Developer Edition** `17.0.1125.2` (**default instance `MSSQLSERVER`**, collation
`SQL_Latin1_General_CP1_CI_AS`, `max server memory` **2560 MB**, **no user
databases yet**) · SSMS 22 · Tailscale · ASP.NET Core **Hosting Bundle 10.0.11**
(`10.0.11.26373`) · **win-acme 2.2.9.1701** at `C:\win-acme`

Also present: **Flutter 3.47.2** (Dart 3.13.2) at `C:\flutter` · **GitHub Actions
runner 2.337.0** at `C:\actions-runner`, registered as `WIN-0ACVT28D53I` and
running as a service · **dotnet-ef 10.0.11** global tool

**Not present, and assumed by parts of this runbook:** `winget`.

IIS serves the three production sites (Step 4); **Default Web Site is stopped**
with autostart disabled, so the bare IP returns `404`.

---

## 3 · Remaining steps

### Step 3 — Hosting Bundle + web ports ✅ **DONE (2026-09-03)**

The Hosting Bundle turned out to be **already installed** — the earlier "Missing"
note was stale. Verified rather than reinstalled:

```powershell
Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"   # True
Get-WebGlobalModule | Where-Object Name -like "*AspNetCore*"                # AspNetCoreModuleV2
```

`aspnetcorev2.dll` is `20.0.26205.11`, from `Microsoft .NET 10.0.11 - Windows
Server Hosting` (`10.0.11.26373`). No `iisreset` was needed — the global module
was already registered and W3SVC was running.

The .NET SDK is **not** a substitute for the Hosting Bundle: the SDK ships the
runtime, the bundle ships `aspnetcorev2.dll`, the IIS module without which every
request to the API is a `500.19`/`500.21`. Install it *after* IIS (already true).

Firewall rules created (`-Profile Any`, both `Enabled`):

```powershell
New-NetFirewallRule -DisplayName "Octopus HTTP 80"  -Direction Inbound -Protocol TCP -LocalPort 80  -Action Allow -Profile Any
New-NetFirewallRule -DisplayName "Octopus HTTPS 443" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -Profile Any
```

Windows' own `World Wide Web Services (HTTP/HTTPS Traffic-In)` rules were already
enabled on all profiles, so 80/443 were open before this. The named Octopus rules
are deliberate redundancy: they survive someone toggling the IIS Windows feature,
which is what owns the built-in rules.

**Checkpoint result.** `http://octopus-pos.com` returns the IIS welcome page
(`200`, `Server: Microsoft-IIS/10.0`, `<title>IIS Windows Server</title>`), and all
three hostnames resolve to `51.255.38.247`.

⚠️ **That test is weaker than it looks, and the next session should know why.** The
public IP is bound directly to the `Ethernet` adapter (`51.255.38.247/32`), so a
request from the box *to its own public IP* loops back inside the host and never
reaches OVH's edge. It proves DNS + IIS, not routing.

External ingress was confirmed separately, from off-network: a fetch of
`https://octopus-pos.com` returned **`ECONNREFUSED 51.255.38.247:443`**. A refusal
is a TCP RST from the host, so the SYN did traverse OVH's edge and Windows
Firewall — nothing is listening on 443 yet, which is correct until Step 5. A
*drop* (edge block, or a missing firewall rule) would have surfaced as a timeout
instead. Port 80's external path is not directly proven yet, but it gets proven
for free in Step 5: HTTP-01 validation only succeeds if Let's Encrypt can reach
port 80 from the outside.

### Step 4 — Create the three IIS sites ✅ **DONE (2026-09-03)**

| site / app | id | physical path | bindings | app pool |
|---|---|---|---|---|
| `octopus-site` | 2 | `C:\inetpub\wwwroot\octopus-site` | `*:80:octopus-pos.com`, `*:80:www.octopus-pos.com` | `octopus-site` |
| `pos-api` | 3 | `C:\inetpub\wwwroot\pos-api` | `*:80:api.octopus-pos.com` | `pos-api` |
| `pos-api/dashboard` | — | `C:\inetpub\wwwroot\dashboard` | *(IIS application under `pos-api`)* | `dashboard` |

All three pools are **No Managed Code** (`managedRuntimeVersion=""`): `pos-api`
because ASP.NET Core runs through ANCM, the other two because they serve static
files. The dashboard gets its **own** pool so an API recycle does not stall it.

Verified by host header — each name returns its own placeholder, and
`/dashboard/` returns the child application, so the nesting resolves.

**Default Web Site is stopped, not deleted**, with `serverAutoStart:false` so it
stays down across reboots. Its `*:80:` catch-all is released either way (the bare
IP now returns `404` instead of the IIS welcome page), and stopping is reversible.
Delete it if you prefer — nothing depends on it.

🚨 **URL Rewrite is a hard prerequisite and was missing.** Installed 2026-09-03:
**2.1** (`7.2.1993`), from
`https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi`.
Both `Back-End/Web-POS.Api/web.config` and `octopus_dashboard_web/web/web.config`
open a `<rewrite>` section, and IIS does **not** ship that module — without it
every request to the API and the dashboard fails with
`500.19 — unrecognized configuration section 'system.webServer/rewrite'`, which
reads like a broken deploy rather than a missing module. Reinstate it first if
this box is ever rebuilt.

ℹ️ **`winget` does not exist on this server.** Any runbook step written as
`winget install ...` has to be done by downloading the MSI directly.

**Child-application inheritance is already handled** — do not "tidy" it away.
`Back-End/Web-POS.Api/web.config` wraps everything in
`<location path="." inheritInChildApplications="false">`, which is what stops the
`aspNetCore` handler (`path="*"`) and the HTTPS-redirect rule from being inherited
by `/dashboard`. Remove that wrapper and the dashboard starts being served by
ANCM instead of as static files. That same redirect rule already exempts
`/.well-known/acme-challenge/`, which is what keeps win-acme renewals working
once HTTPS redirection is live.

⚠️ **Unverified: dashboard deep links.** `octopus_dashboard_web/web/web.config`
rewrites unmatched URLs to `url="/"`. In a child application a leading `/` may
resolve to the **site** root (the API) rather than the application root, which
would break refreshing on a sub-route like `/dashboard/orders` while
`/dashboard/` itself works. The deploy workflow's health check only fetches
`/dashboard/`, so it would **not** catch this. Test a deep link by hand after the
first dashboard deploy; if it 404s or returns API JSON, change the action to
`url="index.html"` (relative, resolves inside the application).

### Step 5 — TLS with win-acme ✅ **DONE (2026-09-03)**

win-acme **2.2.9.1701** (x64 pluggable) installed to **`C:\win-acme`**. The path
matters: the renewal scheduled task invokes `wacs.exe` by absolute path, so moving
the folder silently breaks renewals.

One certificate covers all three names:

| | |
|---|---|
| Subject | `CN=octopus-pos.com` |
| SANs | `octopus-pos.com`, `www.octopus-pos.com`, `api.octopus-pos.com` |
| Issuer | `CN=YR1, O=Let's Encrypt` |
| Valid | 2026-09-03 → **2026-12-02** |
| Thumbprint | `7E23181734CFFC8C3EA364C85B35F3F2895A8A40` |
| Store | `LocalMachine\WebHosting` |
| Renewal | task `win-acme renew (acme-v02.api.letsencrypt.org)`, due **2026-10-29** |

Issued with:

```powershell
C:\win-acme\wacs.exe --source iis --siteid 2,3 --validation filesystem `
  --store certificatestore --installation iis `
  --emailaddress "ilyasschah18@gmail.com" --accepttos
```

`--source iis --siteid 2,3` reads the hostnames straight off the sites' HTTP
bindings, so one cert spans both sites and `--installation iis` writes all three
`*:443:` bindings itself. Re-run that exact line to rebuild from scratch.

**Test against staging first, and use `--baseuri`, not `--test`.** `--test` adds
interactive prompts ("Try in default browser?"); with stdin redirected the console
read throws and it aborts mid-challenge, which looks like a validation failure but
is not. This works unattended:

```powershell
C:\win-acme\wacs.exe --baseuri "https://acme-staging-v02.api.letsencrypt.org/" `
  --source iis --siteid 2,3 --validation filesystem --installation none ...
```

Staging leaves a certificate, two `(STAGING)` CA certs and its own scheduled task
behind — all were cleaned up. Nothing staging-signed ever reached Trusted Root.

**Port 80's external path is now proven.** Let's Encrypt validated all three names
by HTTP-01 from the public internet, which is end-to-end proof of DNS + OVH edge +
Windows Firewall + IIS that no test run *on* the box can give (gotcha 13). Port 80
must stay open permanently or renewals fail. The CAA record already authorises
Let's Encrypt.

Verified from off-network afterwards: all three hostnames serve over HTTPS with a
publicly-trusted chain, including `https://api.octopus-pos.com/dashboard/`.

✅ **The marketing site now redirects HTTP → HTTPS (added 2026-09-03).**
`website/public/web.config` previously had no `<rewrite>` section at all, so
`octopus-pos.com` and `www.` answered on plain HTTP indefinitely while
`api.` did not. It now carries the same rule as the API, **including the
`/.well-known/acme-challenge/` exemption — never remove that condition.**

Verified live, not just by inspection:

| request | result |
|---|---|
| `http://octopus-pos.com/` | `301` → `https://octopus-pos.com/` |
| `http://octopus-pos.com/pricing?plan=pro` | `301` → path **and query** preserved |
| `http://www.octopus-pos.com/` | `301` → `https://www.octopus-pos.com/` (host kept, not folded to apex) |
| `http://octopus-pos.com/.well-known/acme-challenge/…` | **not redirected** |

Then proved end-to-end with a fresh staging issuance *while the redirect was
live*: both names returned `Authorization result: valid`.

🚨 **Cached ACME authorizations will fake a passing test.** A repeat staging run
skips validation entirely and jumps to "Downloading certificate" — ACME caches
authorizations for ~30 days, so it proves nothing about a change you just made.
To force real validation, delete
`C:\ProgramData\win-acme\acme-staging-v02.api.letsencrypt.org` first (staging
only — it holds the account, so a new one is created with no cached authz).

### Step 6 — Database

1. ✅ **Patch SQL Server first — DONE (2026-09-03).** The server is now
   **`17.0.1125.2`**, matching the backup source exactly, so the restore is
   unblocked. Collation and the 2560 MB memory cap both survived the patch.

   A fresh install starting at `17.0.1000.7` was **normal, not a failed
   install** — SQL Server media always installs the RTM baseline, CUs are never
   slipstreamed into it. `ILYASS-DESK` was ahead only because Windows Update had
   already patched it. Same product, same major version, one CU apart.
2. ✅ **Restore `web-pos` — DONE (2026-09-03).** Restored from
   `…\MSSQL\Backup\web-pos.bak` (13.8 MB full backup taken on `ILYASS-DESK`).
   The backup's embedded paths already matched this server's layout (both are
   default instances), but `MOVE` was given explicitly anyway.

   | | |
   |---|---|
   | state | `ONLINE`, owner `WIN-0ACVT28D53I\Administrator` |
   | collation | `SQL_Latin1_General_CP1_CI_AS` — matches server **and** tempdb |
   | compatibility level | **120** (SQL Server 2014), preserved from the source |
   | recovery model | `FULL` |
   | contents | 59 tables · 26 views · 8 procedures · 107 foreign keys |
   | files | data 12.0 MB, log **120.8 MB** |
   | EF history | present, **16 migrations**, latest `20260825122541_AddModifierGroupIcon` |

   The collation was verified behaviourally, not just by reading metadata: a join
   between a restored table's string column and a `#temp` table returns rows
   instead of `Cannot resolve the collation conflict`. That is the failure gotcha 6
   warns about, and it does not occur here.

   ⚠️ **Compatibility level 120 is deliberate — do not "upgrade" it.** It is
   further evidence this schema predates the current dev box (see gotcha 6).
   Raising it changes the query optimiser's behaviour and can alter plans across
   the whole application; it is a tested change, not a tidy-up.

   ⚠️ **`FULL` recovery with no log backups will grow the log without bound.**
   The log is already 10× the data (120.8 MB vs 12.0 MB). Either schedule log
   backups or switch to `SIMPLE` — an open decision, not done here, because it
   trades away point-in-time recovery.
3. ✅ **Create `web-pos-master` — DONE (2026-09-03).** Ran
   `docs/sql/master-db-schema.sql` (7 batches, split on `GO`). Tables: `AdminUser`,
   `BillingEvent`, `DeviceRegistry`, `Subscription`, `Tenant`.

   The explicit `COLLATE` did its job — verified
   `web-pos` = `web-pos-master` = server = `tempdb`, all
   `SQL_Latin1_General_CP1_CI_AS`. **Production is uniform where dev is not.**
4. ✅ **Application login — DONE (2026-09-03).** Login **`pos_app_user`**
   (SQL auth), `DEFAULT_DATABASE = web-pos`, `CHECK_POLICY = ON`,
   `CHECK_EXPIRATION = OFF` (service account).

   The restored `web-pos` contained **no non-system database users at all**, so
   both the login and the database users were created from scratch — there was no
   orphaned SID to remap.

   **Granted, on `web-pos` and `web-pos-master` alike:** `db_datareader` +
   `db_datawriter`. That is all.

   **Deliberately NOT granted:** `sysadmin`, any server role beyond `public`,
   `db_owner`, `db_ddladmin`, and `EXECUTE`. The API calls **no stored
   procedures** (no `FromSqlRaw`, `FromSqlInterpolated`,
   `CommandType.StoredProcedure`, raw `EXEC` — the 8 procedures in `web-pos` are
   legacy and unused), and never calls `EnsureCreated` or `Database.Migrate()`.

   ✅ **The API used to do runtime DDL in one place. That was removed rather than
   granted for (2026-09-03).** `Services/CompanyService.cs` (delete a company) and
   `Services/CompanyDataResetService.cs` both ran
   `ALTER TABLE … NOCHECK CONSTRAINT ALL` around their deletes, needing `ALTER` on
   50 tables. They now delete in foreign-key dependency order instead — see
   `Services/ForeignKeyDeleteOrder.cs`. Read/write is genuinely sufficient.

   `handoff.md` notes `pos_app_user` maps to **dbo** on `ILYASS-DESK`, which is
   why this never surfaced in dev.

   Verified as the login itself, not just from the grants: connects to both
   databases; sees 59 and 5 tables; `SELECT`/`INSERT`/`UPDATE`/`DELETE` all
   succeed (exercised for real inside a transaction and rolled back — nothing
   persisted); `ALTER` is `0` and `CREATE TABLE` is refused.

   ⚠️ **`tools/update-database.ps1` still needs DDL — the one remaining case.**
   It reads the connection string out of the deployed `web.config`, so migrations
   run as `pos_app_user`. Unlike the company sweep (which was user-triggered at
   any moment, and is now fixed in code), migrations are a deliberate manual step
   after a deploy, so a temporary grant is a genuine fit:

   ```sql
   USE [web-pos]; ALTER ROLE db_ddladmin ADD MEMBER [pos_app_user];   -- before
   -- ./tools/update-database.ps1
   USE [web-pos]; ALTER ROLE db_ddladmin DROP MEMBER [pos_app_user];  -- after
   ```

   Keep it a deployment-window grant, not a standing one. The runtime credential
   is read/write and there is no longer any runtime feature that needs more.

   🔑 **The password is not in this repository and must never be.** It exists only
   in the GitHub secrets `PROD_DB_CONNECTION_STRING` and
   `PROD_MASTER_DB_CONNECTION_STRING`. To rotate:
   `ALTER LOGIN [pos_app_user] WITH PASSWORD = N'<new>';` then update both secrets
   and redeploy so `web.config` is rewritten.

**No collation work is needed on the server** — see gotcha 6 for why, and for
what to check if `web-pos` is ever re-sourced from a different machine.

### Step 7 — Runner, secrets, first deploy ← **RESUME HERE**

1. ✅ **Flutter — DONE (2026-09-03).** **3.47.2** stable (Dart **3.13.2**) at
   **`C:\flutter`**, which is not a preference: the dashboard workflow hardcodes
   `C:\flutter\bin\flutter.bat`. Dart 3.13.2 satisfies
   `octopus_dashboard_web`'s `sdk: ^3.12.2`.

   Also done, so the first deploy does not have to: `flutter config
   --no-analytics`, `flutter precache --web`, and
   `git config --global --add safe.directory C:/flutter` (the workflow sets this
   too — the runner service runs as a different account than the one that
   unpacked the SDK, and git refuses a repo it sees as another user's).

   ⚠️ **Let the unpack finish before running `flutter` the first time.** Invoking
   it against a half-extracted tree fails with `The system cannot find the path
   specified` followed by `Found no pubspec.yaml … Unable to 'pub upgrade'
   flutter tool`, retrying ten times. It looks like a broken SDK; it is just a
   race. `bin/flutter.bat` appears long before the tree is complete, so check the
   extraction actually exited rather than testing for that file.

   **Proven, not assumed** — the workflow's own build was run by hand:
   `flutter pub get` then
   `flutter build web --release --base-href /dashboard/` succeeded in 140 s,
   emitting `main.dart.js` and a correct `<base href="/dashboard/">`.
   `octopus_dashboard_web/web/web.config` lands in `build/web/` as expected
   (Flutter copies `web/` verbatim), so it survives the deploy's `robocopy /MIR`
   and the nested application keeps its SPA rewrite.
2. ✅ **GitHub Actions runner — REGISTERED (2026-09-04).** **2.337.0** at
   `C:\actions-runner`, agent name **`WIN-0ACVT28D53I`**, labels
   `self-hosted, Windows, X64, octopus-prod`. Service
   `actions.runner.ilyasschah-POS-APP.WIN-0ACVT28D53I` is **Running / Automatic**
   and connected to the broker.

   `self-hosted` and `Windows` are applied automatically; only **`octopus-prod`**
   is manual. All three workflows target
   `runs-on: [self-hosted, Windows, octopus-prod]`, so a missing label leaves
   jobs queued forever with no error.

   🚨 **The service runs as `NT AUTHORITY\NETWORK SERVICE`, which currently
   cannot write anywhere the deploys need.** Measured 2026-09-04:

   | path | NETWORK SERVICE has | deploy needs |
   |---|---|---|
   | `C:\inetpub\wwwroot\pos-api` | **nothing** (only IIS_IUSRS `RX`, SYSTEM, Administrators) | create + modify + **delete** (`robocopy /MIR`) |
   | `C:\inetpub\wwwroot\octopus-site` | **nothing** | same |
   | `C:\inetpub\wwwroot\dashboard` | **nothing** | same |
   | `C:\flutter` | `RX` only, via `Users` ← `Authenticated Users` | write `bin\cache`, **delete** `bin\cache\lock_file` |

   ✅ **Granted 2026-09-04** — without it every deploy fails at its first file
   copy:

   ```powershell
   foreach ($p in @("C:\inetpub\wwwroot\pos-api","C:\inetpub\wwwroot\octopus-site",
                    "C:\inetpub\wwwroot\dashboard","C:\flutter")) {
       icacls $p /grant "NT AUTHORITY\NETWORK SERVICE:(OI)(CI)M" /T
   }
   ```

   Verified the ACE propagated to existing children, not just the folders:
   `C:\flutter\bin\cache\dart-sdk\bin\dart.exe` reports
   `NT AUTHORITY\NETWORK SERVICE:(I)(M)`.

   **Filesystem rights are all that is required — deliberately.** The backend
   workflow takes the app offline by writing `app_offline.htm`, which ANCM
   watches for, rather than recycling the app pool: *"no IIS management API
   rights, so it works from a low-privilege runner service account."* None of the
   three workflows calls `appcmd`, `iisreset` or `WebAdministration`. Do not
   "fix" a permission problem by making the runner an administrator.
3. ⏳ **Repository secrets — values generated, NOT yet added.** All four were
   generated on the server and handed to the owner directly; **none of them is in
   this repository and none ever may be.** Add at
   `https://github.com/ilyasschah/POS-APP/settings/secrets/actions`:

   | secret | becomes | notes |
   |---|---|---|
   | `PROD_DB_CONNECTION_STRING` | `ConnectionStrings__DefaultConnection` | `Server=localhost`, user `pos_app_user` |
   | `PROD_MASTER_DB_CONNECTION_STRING` | `ConnectionStrings__MasterConnection` | same login, `web-pos-master` |
   | `PROD_JWT_SECRET` | `Jwt__Secret` | 64 chars; **minimum 32**, and must not be one of `JwtSettings.KnownPlaceholders` or startup aborts |
   | `PROD_ADMIN_PORTAL_SEED_PASSWORD` | `AdminPortal__SeedPassword` | see the warning below |

   ⚠️ Both connection strings take **`Server=localhost`** — the instance is no
   longer named, see gotcha 3.

   🚨 **`PROD_ADMIN_PORTAL_SEED_PASSWORD` is not optional in practice.** The
   workflow only *warns* if it is missing and deploys anyway — and then, if the
   Master DB has no admin account yet, `/admin` is seeded with the default
   password **from the source of a public repository, on a public hostname**.
   Set it before the first deploy, not after.

   Every value is generated from an alphabet that excludes `< > & " '` and
   `; = { }`: these land in `web.config` as XML attribute values, so both XML and
   connection-string metacharacters would corrupt them.
4. ℹ️ **Migration history — reconciled 2026-09-04. Not the blocker it first
   looked like.**

   🚨 **Counting files in `Migrations/` is NOT how EF counts migrations.** The
   folder holds 17 `.cs` files but EF knows only **15**. Two were hand-written
   (note the `…000001` IDs) and have **no `.Designer.cs`** — that partial is
   where the `[Migration("…")]` attribute lives, so without it EF never registers
   the class at all:

   ```
   20260520000001_AddCashInOutToZReport     no Designer -> invisible to EF
   20260524000001_AddDueDateToPosOrder      no Designer -> invisible to EF
   ```

   Both changes ARE in the schema (`ZReport.TotalCashIn` / `TotalCashOut` as
   `decimal(18,2) NOT NULL`, `PosOrder.DueDate` as `datetime2 NULL`), and
   `AddDueDateToPosOrder` already had a hand-inserted history row
   (`ProductVersion 9.0.8`) — so recording these by hand is the established
   practice here. `AddCashInOutToZReport` was recorded to match on 2026-09-04:

   ```sql
   USE [web-pos];
   INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
   VALUES (N'20260520000001_AddCashInOutToZReport', N'10.0.11');
   ```

   **Because EF cannot see either migration, neither was ever "pending" and
   `/health/ready` was never going to 503 on them.** The history rows are inert
   to `GetPendingMigrationsAsync`, which compares the *assembly's* migrations
   against the table. Their value is future-proofing: if anyone ever scaffolds
   those two properly, EF will skip them instead of trying to add columns that
   already exist and failing with SQL 2705.

   Verified after the insert: `dotnet ef migrations list --context
   Api.DataBase.AppDbContext` → **15 known, 0 marked (Pending)**. Use the
   **global** tool (`~/.dotnet/tools/dotnet-ef.exe`, 10.0.11); the repo's
   `.config/dotnet-tools.json` pins 9.0.8 against an EF Core 10 project.

   ⚠️ The two unregistered migrations are also the likeliest explanation for
   gotcha 2 (`AppDbContext` has model changes no migration captures). Treat that
   as still open.
5. ✅ **Clone-audit table — FIXED (2026-09-04).**

   `Startup/DatabaseBootstrapper.cs` runs `EnsureCloneAuditTableAsync(master)`
   and `AdminUserSeeder.EnsureTableAsync(master)` on every boot — both **DDL**
   against `web-pos-master`. `dbo.TransactionAudit` did not exist there, and
   `pos_app_user` is `db_datareader` + `db_datawriter`, so it failed with
   `CREATE TABLE permission denied in database 'web-pos-master'`. The
   bootstrapper catches that, so the API would still start and `/health/ready`
   would still pass — with `AdminPortalReady = false` and **`/admin` dead**. A
   silent failure, exactly as the code predicts: *"the likely one on a server
   where the API's SQL login is not db_owner."*

   Fixed by provisioning the table up front instead of granting DDL:
   `docs/sql/master-db-schema.sql` now carries the `TransactionAudit` block
   copied byte-for-byte from `EnsureCloneAuditTableAsync`, alongside the
   `AdminUser` block it already mirrored. Re-running the script created it.

   **Why that is enough:** both bootstrap statements are wrapped in
   `IF OBJECT_ID(...) IS NULL`, and SQL Server checks permissions when a
   statement *executes*, not when the batch compiles. With the table present the
   `CREATE` branch never runs, so no DDL right is exercised. Verified by running
   both statements verbatim as `pos_app_user` — **both succeeded**, while a bare
   `CREATE TABLE` as that same login is still denied.

   ⚠️ **Keep the two copies in step.** If the definition in
   `DatabaseBootstrapper.cs` ever changes, change the SQL file too — otherwise
   the guard finds a table with the wrong shape and the mismatch surfaces as
   runtime query errors, not as a create failure.
6. **Full-stack boot rehearsal — PASSED (2026-09-04).** The API was run by hand
   on `http://127.0.0.1:5099` as `pos_app_user`, `ASPNETCORE_ENVIRONMENT=Production`,
   against the real `web-pos` and `web-pos-master`:

   | check | result |
   |---|---|
   | startup banner | POS database **connected** · Control plane **connected** · Admin accounts **ready** |
   | `GET /health` | `200 {"status":"ok"}` |
   | `GET /health/ready` | `200 {"status":"ready","database":"ok"}` — no pending migrations |
   | `GET /admin/login` | `200`, "Sign in - POS Admin", antiforgery token present |
   | `POST /admin/login` | `302`, `admin_portal_session` cookie issued |
   | `GET /admin/companies` | `200`, "Companies Dashboard - POS Admin" |
   | `GET /swagger*` | `401` — same as any other authenticated route, **not** serving |

   So gotcha 10 holds, with a caveat worth knowing: the startup banner prints a
   Swagger link unconditionally (`Startup/StartupConsole.cs`), so seeing that
   line in Production is **not** evidence Swagger is exposed. Fetch it.

   The rehearsal seeded `Admin` with a throwaway password; **the row was then
   deleted**, because `SeedFirstAdminAsync` is inert once any account exists and
   would otherwise have left the real `PROD_ADMIN_PORTAL_SEED_PASSWORD` with
   nothing to do. `dbo.AdminUser` is empty, so the first deploy seeds it properly.

   Also expected on that boot: `Failed to determine the https port for redirect`
   (gotcha 9 — no `ASPNETCORE_HTTPS_PORT` was set locally, which is why plain
   HTTP served) and a warning that a new `lease_signing_key.pem` would be
   generated. No key was actually written — it is created lazily on first lease
   issuance, so nothing had to be cleaned up (gotcha 7).
7. Create the `prod` branch and push → all three workflows fire.

   ⚠️ This is the irreversible one, and it fires **three production deploys at
   once** on a public repo. Everything above it is now done except **step 3, the
   repository secrets** — without those the backend deploy either fails its guard
   or seeds a public default password.

---

## 4 · Gotchas — every one of these was learned the hard way

1. **There is no baseline migration.** The earliest is
   `20260430101242_AddUserIdToBooking`, a delta. Running `dotnet ef database update`
   against an empty database creates `__EFMigrationsHistory` and nothing else, then
   fails with `Cannot find the object "Booking"`. The schema predates EF migrations,
   so **the production database must come from a backup/restore**, never from
   migrations alone.

2. **`AppDbContext` has pending model changes.** EF 10 refuses `database update`
   until a migration captures them. Creating migrations is reserved to the owner
   (see `CLAUDE.md`), so this is an open decision, not a task.

3. **SQL is the DEFAULT instance — this changed on 2026-09-03.** Express was
   uninstalled and replaced with Developer Edition using the default instance, so
   connection strings now use `localhost` (or `.` / `(local)`), **not**
   `.\SQLEXPRESS`, which no longer resolves. This costs little only because
   nothing hardcodes the server: `tools/update-database.ps1` reads the connection
   string out of the deployed `web.config`, and the production strings live in
   GitHub secrets. Write `PROD_DB_CONNECTION_STRING` and
   `PROD_MASTER_DB_CONNECTION_STRING` with `Server=localhost` when you create them
   in Step 7. `SQLBrowser` is stopped and disabled — correct for a default
   instance, which needs no name resolution.

4. ⚠️ **Two commercial licences are unresolved. Both are the owner's call, and
   neither blocks a deploy.**

   **SQL Server Developer Edition is not licensed for production.** It is free
   because Microsoft licenses it for development and test use only. It runs on
   this production host as a deliberate, informed decision by the owner
   (2026-09-03). The licensed route to the same capability is **Standard
   Edition**.

   **MediatR 14.2.0 now requires a paid licence for production.** The API logs
   this on every boot (observed 2026-09-04): *"You do not have a valid license
   key … This is allowed for development and testing scenarios. If you are
   running in production you are required to have a licensed version."* MediatR
   went commercial under Lucky Penny Software; the API uses it for CQRS
   throughout, so this is not a dependency that can simply be dropped. Either buy
   a key or plan the migration.

   Revisit both before the deployment is treated as commercially supported.

5. **Memory must be capped by hand now.** Express enforced a ~1410 MB buffer pool
   that was implicitly protecting IIS on this 7.8 GB box; Developer has no such
   cap and defaults to unlimited, so it will grow until it competes with IIS and
   the API. `max server memory` is therefore set to **2560 MB**. Do not remove
   this. There is no size limit to worry about any more (Express's was 10 GB;
   the databases are 12 MB + 8 MB).

6. **Collations differ between the two databases, and production is the one that
   is right.** Measured 2026-09-03:

   | | `web-pos` | `web-pos-master` | server / tempdb |
   |---|---|---|---|
   | `ILYASS-DESK` (dev) | `SQL_Latin1_General_CP1_CI_AS` | `Latin1_General_CI_AS` | `Latin1_General_CI_AS` |
   | Production | *(from restore)* `SQL_…CP1_CI_AS` | *(from script)* `SQL_…CP1_CI_AS` | `SQL_Latin1_General_CP1_CI_AS` |

   `web-pos` predates the current dev box and carries the legacy SQL collation.
   `web-pos-master` was created later by `docs/sql/master-db-schema.sql`, whose
   `CREATE DATABASE` had **no `COLLATE` clause**, so on dev it silently inherited
   that machine's Windows collation and the two drifted apart. The script now
   pins `COLLATE SQL_Latin1_General_CP1_CI_AS` explicitly, so production comes out
   uniform: every database *and* `tempdb` on one collation.

   **Do not "fix" the production server collation to match dev.** It is already
   correct. Rebuilding system databases here would be actively wrong — it would
   put `tempdb` out of step with the restored `web-pos` and break the first query
   that joins a restored string column to a `#temp` table with
   `Cannot resolve the collation conflict`. The dev box is the inconsistent one;
   production being uniform matters more than matching it.

   If `web-pos` is ever re-sourced from a different machine, check
   `SELECT name, collation_name FROM sys.databases` on that source **before**
   restoring — the backup carries the database's own collation, and it is the
   server collation it has to agree with.

7. **Never delete `lease_signing_key.pem`** from the API folder. It signs every
   offline licence lease; losing it invalidates every lease already issued to
   customer terminals, with no way back. The deploy workflow excludes it from
   `robocopy /MIR` for exactly this reason.

8. **This repository is public.** No secrets in git, ever. A private key
   (`server-pos.ppk`) was once sitting untracked in the repo root while the
   runbook's Step 1 says `git add .`; `.gitignore` now covers `*.ppk`, `*.pem`,
   `*.key`. It was never committed.

9. **The OVH Edge Network Firewall is stateless** and defaults to DENY ALL. It is
   deliberately **disabled**. Turning it on without a sequence-0 "TCP established"
   rule (and a UDP source-port-53 rule for DNS replies) silently kills all the
   server's *outbound* traffic — Windows Update, NuGet, npm, git. Windows Firewall
   is stateful and is doing the filtering instead.

10. **A Tailscale IP can never be used in the OVH firewall.** `100.64.0.0/10` is a
    private overlay range; OVH's edge matches on real public source addresses, so
    such a rule matches nothing at all while looking configured.

11. **`ASPNETCORE_HTTPS_PORT=443` is mandatory.** `Program.cs` enables
    `UseHttpsRedirection()` in Production, and behind IIS that middleware cannot
    always infer the port — on failure it logs
    `Failed to determine the https port for redirect` and then does nothing,
    silently serving plain HTTP. The deploy workflow sets it.

12. **Swagger is disabled in Production.** If `/swagger` ever answers on
    production, `ASPNETCORE_ENVIRONMENT` is not set to `Production` — treat it as
    a misconfigured deploy.

13. **You cannot smoke-test this box from itself.** `51.255.38.247` is bound
    directly to the `Ethernet` adapter, so any request from the server to its own
    public IP or hostname loops back inside the host and never touches OVH's edge.
    It will happily return `200` while the site is unreachable to the entire
    internet. This applies to every later check too — `api.octopus-pos.com`,
    `/dashboard`, `/health`. Verify from off the box (a phone on mobile data works;
    so does anything not on the tailnet). Distinguishing the two failure modes:
    **connection refused** = packets arrive, nothing is listening; **timeout** =
    packets are being dropped by a firewall or never routed.

---

## 5 · What already changed in the repo

- `Program.cs` — Swagger gated to non-Production; HSTS + HTTPS redirect in
  Production; new `/health` (liveness) and `/health/ready` (readiness, reports
  **pending migrations** as 503 so a schema-behind-code deploy fails loudly).
- `Front-End/lib/core/config.dart` + `octopus_dashboard_web/lib/core/constants.dart`
  — default endpoint is now `https://api.octopus-pos.com/api`, with a
  **Production** entry in both environment pickers. This fixed a real bug: the
  compiled default was a **Tailscale** address, and no release workflow overrides
  it, so every shipped installer pointed somewhere unroutable.
- Three production workflows on the `prod` branch; the two dead `-test` ones removed.
- `tools/update-test-database.ps1` → `tools/update-database.ps1`.
- `website/` builds as a **static export** (`output: "export"`) plus
  `website/public/web.config` — IIS serves nothing whose extension it lacks a MIME
  map for, and `.webp` is unmapped by default, so the logo would have 404'd.
- `RELEASE_RUNBOOK.md`, `POS_ONSITE_CHECKLIST.md` rewritten for production.
