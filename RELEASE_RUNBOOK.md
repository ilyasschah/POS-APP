# Release Runbook

From a change on your dev machine to live servers and downloadable installers.

**Production API:** https://api.octopus-pos.com · **Marketing site:** https://octopus-pos.com

| What ships | Where it lives | Current version | How it ships |
|---|---|---|---|
| **Backend API** | `Back-End/` | — | `prod` push → IIS at `api.octopus-pos.com` |
| **Admin portal** | inside the backend | — | same deploy, served at `/admin` |
| **Owner Dashboard (web)** | `octopus_dashboard_web/` | `1.0.0+1` | `prod` push → `api.octopus-pos.com/dashboard/` |
| **Marketing website** | `website/` | — | `prod` push → `octopus-pos.com` |
| **POS app** | `Front-End/` | `1.0.12+15` | tag `v*` → Windows `.exe` + macOS `.dmg` |
| **Kitchen Display** | `kitchen_display/` | `1.0.12+2` | tag `kds-v*` → Windows `.exe` + Android `.apk` |
| **Owner Dashboard (iOS)** | `Octopus_Dashboard/` | not released | **no CI** — Xcode by hand, and it still points at a dead server. See below. |

Latest tags: **`v1.0.12`** (POS) and **`kds-v1.0.12`** (KDS).

---

## What triggers what

| You do this | This happens automatically |
|---|---|
| Push to **`prod`** touching `Back-End/**` | Backend + admin portal deploy |
| Push to **`prod`** touching `octopus_dashboard_web/**` | Dashboard deploys |
| Push to **`prod`** touching `website/**` | Marketing site deploys |
| Push a **`v*`** tag | POS Windows installer + macOS DMG → GitHub Release |
| Push a **`kds-v*`** tag | KDS Windows installer + Android APK → GitHub Release |
| Push to **`main`** | **Nothing.** `main` is the source of truth, not a deploy trigger. |

🚨 **Every server workflow is path-filtered.** A push to `prod` that only touches
`Front-End/` deploys **nothing** — no workflow runs, no failure, no notification.
This is a feature (a POS-only change should not restart the API) but it is the
first thing to check when "I pushed to prod and nothing happened."

To deploy a component whose files did not change, use **Actions → the workflow →
Run workflow** (`workflow_dispatch` is enabled on all three).

**The database is never automatic.** You run it by hand, on the server. Step 4.

> **This is production.** There is no test server any more — the OVH box that
> served `51-91-6-6.sslip.io` was deleted. A bad push to `prod` is visible to real
> customers, so Step 4's `-WhatIf` is no longer optional politeness.

All three deploy workflows run on the **self-hosted runner installed on the OVH box
itself**. If the runner is offline the job queues forever — check the server before
assuming a build hung. Tag builds are different: they run on **GitHub-hosted**
runners (`windows-latest`, `macos-latest`) and never touch the server.

---

## Step 1 — Commit your work

```powershell
cd E:\POS-APP
git status
git add .
git commit -m "fix(pos): what you changed"
git push origin <your-branch>
```

## Step 2 — Merge into main

```powershell
git checkout main
git pull origin main
git merge <your-branch>
git push origin main
```

✅ **Check:** `git log --oneline -3` shows your commit on `main`.

## Step 3 — Deploy to production

Backend, dashboard and website all deploy from the **`prod`** branch.

```powershell
git checkout prod
git pull origin prod
git merge main
git push origin prod
```

Before you push, it is worth knowing what will actually fire:

```powershell
git diff --name-only prod..main    # which top-level folders changed?
```

Watch it run: **GitHub → Actions**, one of

- *Deploy Backend to Production*
- *Deploy Dashboard to Production*
- *Deploy Website to Production*

✅ **Check:** the workflow ends green. Each one asserts on real content, not just a
200 — the backend requires `/health/ready` **and** the `/admin` login page, the
dashboard requires the built Flutter bootstrap script in the HTML, the website
requires the string "Octopus POS" in the page. A stale or empty site fails.

### What the backend deploy actually does

It publishes `Web-POS.Api`, drops `app_offline.htm` so IIS releases the DLL lock,
mirrors the files into `C:\inetpub\wwwroot\pos-api`, then **re-injects the
production secrets** into the freshly generated `web.config` — connection strings,
JWT secret, admin seed password — because `dotnet publish` regenerates that file
from the committed template every single run and those secrets are never in git.

The mirror deliberately excludes `lease_signing_key.pem` and `logs`. See rule 8.

## Step 4 — Update the production database ⚠️

**Only if you added or changed an EF migration.** Skip otherwise.

This does **not** happen in the deploy. The API publishes, the schema stays where it
was, and the first endpoint that reads a new column answers **500**. That is what
happened after `AddSellByWeightAndBarcodeRules`: every sync step touching Product
failed at once, and redeploying could not fix it — the code was already right, the
database was not.

The deploy now *detects* this — `/health/ready` returns 503 listing the pending
migrations, so the workflow fails instead of reporting a healthy-but-broken site. It
still cannot fix it for you.

**Run this on the server** (RDP in — it reads the connection string out of the
deployed `web.config`, so it cannot run from your PC):

```powershell
cd C:\actions-runner\_work\POS-APP\POS-APP     # wherever the runner checked out
git pull

# See what is pending, change nothing:
.\tools\update-database.ps1 -WhatIf

# Apply it:
.\tools\update-database.ps1
```

Other options:

```powershell
.\tools\update-database.ps1 -ScriptOnly   # write the SQL to review first
.\tools\update-database.ps1 -RestartIis   # recycle the site afterwards
```

> Only **`AppDbContext`** owns the migrations. The API has a second context
> (Master), and `dotnet ef` refuses to guess between them — that is why the script
> passes the context for you.

✅ **Check:** it prints the migrations applied, and
`https://api.octopus-pos.com/health/ready` returns 200.

## Step 5 — Release the POS app (Windows + macOS)

Both come from **one tag**. Do this from `main`, with a clean tree.

```powershell
git checkout main
git pull origin main
git status                    # must be clean

.\tools\release.ps1 1.0.13 -WhatIf    # dry run — shows the version bump + tag
.\tools\release.ps1 1.0.13            # do it
```

The script bumps `Front-End/pubspec.yaml`, commits, **then** tags — in that order,
so the tag can never point at a commit carrying the old version. Do not tag by hand;
that has gone wrong twice. It also refuses a dirty tree, refuses an existing tag, and
only ever increments the build number.

Two workflows start on the tag:

- **Release Windows Installer** → `Octopus_POS_Setup_v1.0.13.exe`
- **Release macOS DMG** → `Octopus_POS_v1.0.13.dmg`

Both attach to the same **GitHub Release**. The Mac is built on a GitHub-hosted macOS
runner — you do not need a Mac. Release notes come from the Windows job only, so the
two cannot clobber each other's text.

✅ **Check:** GitHub → Releases → `v1.0.13` has **both** files attached, each with its
`.sha256`.

> **The DMG is ad-hoc signed, not Developer ID / notarized.** It runs, but Gatekeeper
> will tell the customer the app "cannot be opened" or "is damaged" on first launch.
> They need **right-click → Open** the first time (or to clear the quarantine
> attribute with `xattr`). Until there is a paid Apple Developer ID to sign with,
> that instruction ships with every Mac install.

## Step 6 — Release the Kitchen Display

**Separate app, separate version, separate tag prefix.** There is no script for this
one — bump and tag by hand:

```powershell
# 1. edit kitchen_display/pubspec.yaml -> version: 1.0.13+3
git add kitchen_display/pubspec.yaml
git commit -m "chore(kds): release 1.0.13"
git push origin main

git tag kds-v1.0.13
git push origin kds-v1.0.13
```

🚨 **The prefix is `kds-v`, never `v`.** `release-windows.yml` hard-fails when the tag
disagrees with `Front-End/pubspec.yaml`, so a KDS release under a bare `v` tag would
break the POS pipeline every time. The globs do not overlap: `v*` does not match
`kds-v1.0.13`.

Produces **`Octopus_KDS_Setup_v1.0.13.exe`** and **`Octopus_KDS_v1.0.13.apk`** on one
Release. The APK is sideloaded onto the kitchen tablet — it is not on Play.

> **The KDS never talks to the backend.** The POS pushes pairing handshakes and order
> snapshots straight to it over the LAN on **port 9090**, so the kitchen keeps working
> with no internet at all. Deploying the API therefore cannot fix or break a KDS — but
> a POS release that changes the push payload means the KDS must be released with it.
> Keep their version numbers in step (both are at 1.0.12 today for that reason).

## Step 7 — Install and smoke test

Download the installer from the Release, install it on the till, and run
[POS_ONSITE_CHECKLIST.md](POS_ONSITE_CHECKLIST.md).

✅ **The installer's compiled default endpoint is Production**
(`https://api.octopus-pos.com/api`), so a fresh install talks to the right server with
nothing to configure.

> This was a real bug until the production cutover: the compiled default was
> `devBaseUrl`, a **Tailscale** address, and neither release workflow passes
> `--dart-define=API_BASE_URL`. Every installer built from this repo shipped pointing
> at an endpoint no customer machine on earth could route to. If you ever change
> `defaultApiBaseUrl` in `Front-End/lib/core/config.dart`, that is what you are
> changing.

To build against a different backend without touching source:

```powershell
flutter build windows --dart-define=API_BASE_URL=https://your-endpoint/api
```

---

## The iOS Owner Dashboard is not in this pipeline

`Octopus_Dashboard/` is a native SwiftUI iPhone app plus a home-screen widget
(`OwnerWidget`). It has **no workflow** — it is built and distributed from Xcode on a
Mac, which is why nothing above mentions it.

⚠️ **It is currently pointed at a server that no longer exists.**
`AuthManager.swift` hardcodes `https://51-91-6-6.sslip.io/api`, the deleted OVH test
box. It cannot log in from any device today. Before shipping it anywhere, repoint it
at `https://api.octopus-pos.com/api`.

The **web** dashboard (`octopus_dashboard_web/`) is the one that is live, and it is an
installable PWA — an owner can "Add to Home Screen" from
`api.octopus-pos.com/dashboard/` and get most of what the native app promised, on both
phones. It is served from the **same origin** as the API on purpose: same-origin calls
mean no CORS and one certificate to keep alive.

---

## If something goes wrong

**Nothing deployed after a `prod` push:** almost always the path filter — you changed
files outside `Back-End/`, `octopus_dashboard_web/` and `website/`. Re-run the
workflow by hand from the Actions tab.

**Tag was wrong / build failed:**

```powershell
git tag -d v1.0.13
git push --delete origin v1.0.13
# fix, then run tools/release.ps1 again        (for KDS: kds-v1.0.13)
```

**Deploy broke production:** revert on `prod` and push — the deploy re-runs.

```powershell
git checkout prod
git revert <bad-commit>
git push origin prod
```

**Migration went wrong:** there is no automatic rollback. Restore the database backup,
or write a down-migration. Use `-ScriptOnly` first next time.

**`/health/ready` returns 503:** read the body. `pendingMigrations` means the code is
ahead of the schema → Step 4. `"database": "unreachable"` means the connection string
or SQL Server itself is the problem → check the server, not the deploy.

**`/admin/login` returns 500:** check the startup log for `ADMIN PORTAL UNUSABLE` —
the `AdminUser` table failed to create in the Master DB. A **302** there is worse: the
login page ended up behind its own login and nobody can sign in.

**`/dashboard/` 404s:** the `dashboard` folder is not configured as an IIS application
under the API site. Copying the files there is not enough on its own.

**Dashboard shows a stale build:** it is a PWA — the service worker serves the old
bundle until it updates. Hard-reload, and check that the deploy's mirror actually
replaced the files.

---

## Rules that are easy to forget

1. **`main` deploys nothing.** Merging to `main` alone changes nothing on any server.
   You must merge into `prod`.
2. **Path filters gate every server deploy.** No matching files, no run at all.
3. **Never `dotnet run`/restart the API from a script while it is under the VS
   debugger** — build only, then restart it yourself.
4. **The DB step is manual and runs on the server**, never from your PC.
5. **`tools/release.ps1` refuses a dirty tree.** Commit first. It only knows about
   `Front-End/` — the KDS is bumped and tagged by hand.
6. **Version only goes up.** The build number is derived for Android and the Play Store
   rejects a decrease.
7. **Real DB credentials live only in `appsettings.Local.json`** (git-ignored) and in
   the deployed `web.config`. Never commit them — **this repository is public.**
8. **Never delete `lease_signing_key.pem` from the server.** It signs every offline
   licence lease. Lose it and every customer terminal's lease stops validating at once,
   with no way to recover the original. The deploy's mirror excludes it for this reason.
9. **Swagger is disabled in Production.** `/swagger` returning **200** on production
   means `ASPNETCORE_ENVIRONMENT` is not set to `Production` — treat that as a
   misconfigured deploy, because the Swagger middleware runs *ahead* of
   `UseAuthorization` and will hand the entire API surface to anyone who asks.
   A **401 there is normal and proves nothing**: the API's global `FallbackPolicy`
   answers 401 for every unmatched route, so a nonexistent path returns the same
   401. Only 200 is the alarm.
10. **The website is a static export.** There is no Node process on the server;
    `next.config.ts` sets `output: "export"` and IIS serves `out/` as plain files. If
    that setting is ever lost the build silently becomes a server bundle IIS cannot
    serve — the workflow checks for `out/index.html` to catch it.
