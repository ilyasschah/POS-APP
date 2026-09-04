# Release Runbook

From a change on your dev machine to a live production server and signed installers.

**Current version:** `1.0.10+13` · **Production:** https://api.octopus-pos.com

---

## What triggers what

| You do this | This happens automatically |
|---|---|
| Push to **`prod`** branch | Backend deploys to production · Dashboard deploys to production |
| Push a **`v*` tag** | Windows installer builds · macOS DMG builds → GitHub Release |
| Push to **`main`** | **Nothing.** `main` is the source of truth, not a deploy trigger. |

**The database is never automatic.** You run it by hand, on the server. Step 4.

> **This is production now.** There is no test server any more — the OVH box that
> served `51-91-6-6.sslip.io` was deleted. A bad push to `prod` is visible to real
> customers, so Step 4's `-WhatIf` is no longer optional politeness.

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

Backend and dashboard both deploy from the **`prod`** branch.

```powershell
git checkout prod
git pull origin prod
git merge main
git push origin prod
```

Watch it run: **GitHub → Actions → "Deploy Backend to Production"** (and *"Deploy Dashboard to Production"*).

Both run on the self-hosted runner **installed on the OVH box itself**. If the runner is offline, the job queues forever — check it on the server before assuming the build hung.

✅ **Check:** the workflow ends green. It only ends green if `/health/ready` returned 200, which means the API is up **and** its schema matches the deployed code.

## Step 4 — Update the production database ⚠️

**Only if you added or changed an EF migration.** Skip otherwise.

This does **not** happen in the deploy. The API publishes, the schema stays where it was, and the first endpoint that reads a new column answers **500**. That is what happened after `AddSellByWeightAndBarcodeRules`: every sync step touching Product failed at once, and redeploying could not fix it — the code was already right, the database was not.

The deploy now *detects* this — `/health/ready` returns 503 listing the pending migrations, so the workflow fails instead of reporting a healthy-but-broken site. It still cannot fix it for you.

**Run this on the server** (RDP in — it reads the connection string out of the deployed `web.config`, so it cannot run from your PC):

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

✅ **Check:** it prints the migrations applied, and `https://api.octopus-pos.com/health/ready` returns 200.

## Step 5 — Build the Windows app + macOS DMG

Both come from **one tag**. Do this from `main`, with a clean tree.

```powershell
git checkout main
git pull origin main
git status                    # must be clean

.\tools\release.ps1 1.0.11 -WhatIf    # dry run — shows the version bump + tag
.\tools\release.ps1 1.0.11            # do it
```

The script bumps `pubspec.yaml`, commits, **then** tags — in that order, so the tag can never point at a commit carrying the old version. Do not tag by hand; that has gone wrong twice.

Two workflows start on the tag:
- **Release Windows Installer** → `Octopus_POS_Setup_v1.0.11.exe`
- **Release macOS DMG** → the `.dmg`

Both attach to the same **GitHub Release**. The Mac is built on a GitHub-hosted macOS runner — you do not need a Mac.

✅ **Check:** GitHub → Releases → `v1.0.11` has **both** files attached.

## Step 6 — Install and smoke test

Download the installer from the Release, install it on the till, and run [POS_ONSITE_CHECKLIST.md](POS_ONSITE_CHECKLIST.md).

✅ **The installer's compiled default endpoint is Production** (`https://api.octopus-pos.com/api`), so a fresh install talks to the right server with nothing to configure.

> This was a real bug until the production cutover: the compiled default was
> `devBaseUrl`, a **Tailscale** address, and neither release workflow passes
> `--dart-define=API_BASE_URL`. Every installer built from this repo shipped
> pointing at an endpoint no customer machine on earth could route to. If you
> ever change `defaultApiBaseUrl` in `Front-End/lib/core/config.dart`, that is
> what you are changing.

To build against a different backend without touching source:

```powershell
flutter build windows --dart-define=API_BASE_URL=https://your-endpoint/api
```

---

## If something goes wrong

**Tag was wrong / build failed:**

```powershell
git tag -d v1.0.11
git push --delete origin v1.0.11
# fix, then run tools/release.ps1 again
```

**Deploy broke production:** revert on `prod` and push — the deploy re-runs.

```powershell
git checkout prod
git revert <bad-commit>
git push origin prod
```

**Migration went wrong:** there is no automatic rollback. Restore the database backup, or write a down-migration. Use `-ScriptOnly` first next time.

**`/health/ready` returns 503:** read the body. `pendingMigrations` means the code is ahead of the schema → Step 4. `"database": "unreachable"` means the connection string or SQL Server itself is the problem → check the server, not the deploy.

---

## Rules that are easy to forget

1. **`main` deploys nothing.** Merging to `main` alone changes nothing on the server. You must merge into `prod`.
2. **Never `dotnet run`/restart the API from a script while it is under the VS debugger** — build only, then restart it yourself.
3. **The DB step is manual and runs on the server**, never from your PC.
4. **`tools/release.ps1` refuses a dirty tree.** Commit first.
5. **Version only goes up.** The build number is derived for Android and the Play Store rejects a decrease.
6. **Real DB credentials live only in `appsettings.Local.json`** (git-ignored) and in the deployed `web.config`. Never commit them — **this repository is public.**
7. **Never delete `lease_signing_key.pem` from the server.** It signs every offline licence lease. Lose it and every customer terminal's lease stops validating at once, with no way to recover the original.
8. **Swagger is disabled in Production.** `/swagger` answering on production means `ASPNETCORE_ENVIRONMENT` is not set to `Production` — treat that as a misconfigured deploy.
