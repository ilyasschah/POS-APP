# Production Server Setup — Octopus POS

Live state of the production cutover, written so a session with **no prior context**
can pick it up. Started 2026-09-03, handed over mid-Step-3 on 2026-09-04.

> **Resume point: Step 3 (3a not yet run).** Steps 1–2 are done and verified.

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

## 2 · Software state at handover

**Present:** IIS · .NET SDK 10.0.400 · ASP.NET Core runtime 10.0.11 · Node v24.20.0 ·
Git 2.55 · SQL Server Express **17.0.1000.7** (instance `SQLEXPRESS`, collation
`SQL_Latin1_General_CP1_CI_AS`, **no user databases yet**) · Tailscale

**Missing:** ASP.NET Core **Hosting Bundle (ANCM)** · Flutter · win-acme ·
GitHub Actions runner

IIS currently has only the stock **Default Web Site** bound to `*:80:`.

---

## 3 · Remaining steps

### Step 3 — Hosting Bundle + web ports ← **RESUME HERE**

```powershell
winget install --id Microsoft.DotNet.HostingBundle.10 -e --accept-package-agreements --accept-source-agreements
iisreset
"aspnetcorev2.dll : " + (Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll")

New-NetFirewallRule -DisplayName "Octopus HTTP 80"  -Direction Inbound -Protocol TCP -LocalPort 80  -Action Allow -Profile Any | Out-Null
New-NetFirewallRule -DisplayName "Octopus HTTPS 443" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -Profile Any | Out-Null
```

The .NET SDK is **not** a substitute for the Hosting Bundle: the SDK ships the
runtime, the bundle ships `aspnetcorev2.dll`, the IIS module without which every
request to the API is a `500.19`/`500.21`. Install it *after* IIS (already true).

Checkpoint: `http://octopus-pos.com` should return the IIS welcome page, proving
DNS + OVH routing + firewall + IIS all work before anything is built on top.

### Step 4 — Create the three IIS sites

- `octopus-site` → `C:\inetpub\wwwroot\octopus-site`, host headers `octopus-pos.com` + `www.octopus-pos.com`
- `pos-api` → `C:\inetpub\wwwroot\pos-api`, host header `api.octopus-pos.com`, app pool **No Managed Code**
- `dashboard` → IIS **application** under `pos-api` at `/dashboard` → `C:\inetpub\wwwroot\dashboard`
- Remove the stock Default Web Site (its `*:80:` catch-all serves the IIS page on the bare IP)

### Step 5 — TLS with win-acme

One certificate for all three names, HTTP-01 over port 80. Port 80 must stay open
permanently for the 60-day renewals. The CAA record already authorises
Let's Encrypt — if it named another CA, issuance would fail with an error that
does not obviously point at DNS.

### Step 6 — Database

1. **Patch SQL Express first.** Local (backup source) is `17.0.1125.2`; the server
   is `17.0.1000.7` RTM. Restores never go backwards, and a CU can bump the
   internal database version. Bring the server to ≥ the source build.
2. Restore `web-pos` from a local backup (12 MB) — see the gotcha below about why
   this cannot come from migrations.
3. Create `web-pos-master` from `docs/sql/master-db-schema.sql` (8 MB locally).
4. Create the application SQL login and grant it both databases.

### Step 7 — Runner, secrets, first deploy

1. Install Flutter to **`C:\flutter`** (the dashboard workflow hardcodes
   `C:\flutter\bin\flutter.bat`).
2. Install the GitHub Actions runner as a service with labels
   **`self-hosted, Windows, octopus-prod`** — all three workflows target them.
3. Add the repository secrets:
   `PROD_DB_CONNECTION_STRING`, `PROD_MASTER_DB_CONNECTION_STRING`,
   `PROD_JWT_SECRET` (≥32 random chars), `PROD_ADMIN_PORTAL_SEED_PASSWORD`.
4. Create the `prod` branch and push → all three workflows fire.

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

3. **SQL is a named instance.** Connection strings must use `.\SQLEXPRESS` —
   `localhost` alone will not resolve it.

4. **Express limits:** 10 GB per database (currently 12 MB + 8 MB, so irrelevant
   for years) and a ~1410 MB buffer pool cap, which conveniently keeps SQL from
   starving IIS on a 7.8 GB box.

5. **Never delete `lease_signing_key.pem`** from the API folder. It signs every
   offline licence lease; losing it invalidates every lease already issued to
   customer terminals, with no way back. The deploy workflow excludes it from
   `robocopy /MIR` for exactly this reason.

6. **This repository is public.** No secrets in git, ever. A private key
   (`server-pos.ppk`) was once sitting untracked in the repo root while the
   runbook's Step 1 says `git add .`; `.gitignore` now covers `*.ppk`, `*.pem`,
   `*.key`. It was never committed.

7. **The OVH Edge Network Firewall is stateless** and defaults to DENY ALL. It is
   deliberately **disabled**. Turning it on without a sequence-0 "TCP established"
   rule (and a UDP source-port-53 rule for DNS replies) silently kills all the
   server's *outbound* traffic — Windows Update, NuGet, npm, git. Windows Firewall
   is stateful and is doing the filtering instead.

8. **A Tailscale IP can never be used in the OVH firewall.** `100.64.0.0/10` is a
   private overlay range; OVH's edge matches on real public source addresses, so
   such a rule matches nothing at all while looking configured.

9. **`ASPNETCORE_HTTPS_PORT=443` is mandatory.** `Program.cs` enables
   `UseHttpsRedirection()` in Production, and behind IIS that middleware cannot
   always infer the port — on failure it logs
   `Failed to determine the https port for redirect` and then does nothing,
   silently serving plain HTTP. The deploy workflow sets it.

10. **Swagger is disabled in Production.** If `/swagger` ever answers on
    production, `ASPNETCORE_ENVIRONMENT` is not set to `Production` — treat it as
    a misconfigured deploy.

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
