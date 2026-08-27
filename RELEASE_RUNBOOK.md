# Release Runbook

From a change on your dev machine to a live Test server and signed installers.

**Current version:** `1.0.5+8` · **Test server:** https://51-91-6-6.sslip.io

---

## What triggers what

| You do this | This happens automatically |
|---|---|
| Push to **`test`** branch | Backend deploys to OVH · Dashboard deploys to OVH |
| Push a **`v*` tag** | Windows installer builds · macOS DMG builds → GitHub Release |
| Push to **`main`** | **Nothing.** `main` is the source of truth, not a deploy trigger. |

**The database is never automatic.** You run it by hand, on the server. Step 4.

---

## Step 1 — Commit your work

```powershell
cd D:\POS-APP
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

## Step 3 — Deploy to the OVH Test server

Backend and dashboard both deploy from the **`test`** branch.

```powershell
git checkout test
git pull origin test
git merge main
git push origin test
```

Watch it run: **GitHub → Actions → "Deploy Backend to OVH Test"** (and *"Deploy Dashboard to OVH Test"*).

Both run on the self-hosted runner **installed on the OVH box itself**. If the runner is offline, the job queues forever — check it on the server before assuming the build hung.

✅ **Check:** the workflow ends green, and https://51-91-6-6.sslip.io/dashboard/ loads.

## Step 4 — Update the Test database ⚠️

**Only if you added or changed an EF migration.** Skip otherwise.

This does **not** happen in the deploy. The API publishes, the schema stays where it was, and the first endpoint that reads a new column answers **500**. That is what happened after `AddSellByWeightAndBarcodeRules`: every sync step touching Product failed at once, and redeploying could not fix it — the code was already right, the database was not.

**Run this on the OVH server** (RDP in — it reads the connection string out of the deployed `web.config`, so it cannot run from your PC):

```powershell
cd C:\actions-runner\_work\POS-APP\POS-APP     # wherever the runner checked out
git pull

# See what is pending, change nothing:
.\tools\update-test-database.ps1 -WhatIf

# Apply it:
.\tools\update-test-database.ps1
```

Other options:

```powershell
.\tools\update-test-database.ps1 -ScriptOnly   # write the SQL to review first
.\tools\update-test-database.ps1 -RestartIis   # recycle the site afterwards
```

✅ **Check:** it prints the migrations applied, and the API answers real data instead of 500.

## Step 5 — Build the Windows app + macOS DMG

Both come from **one tag**. Do this from `main`, with a clean tree.

```powershell
git checkout main
git pull origin main
git status                    # must be clean

.\tools\release.ps1 1.0.6 -WhatIf    # dry run — shows the version bump + tag
.\tools\release.ps1 1.0.6            # do it
```

The script bumps `pubspec.yaml`, commits, **then** tags — in that order, so the tag can never point at a commit carrying the old version. Do not tag by hand; that has gone wrong twice.

Two workflows start on the tag:
- **Release Windows Installer** → `Octopus_POS_Setup_v1.0.6.exe`
- **Release macOS DMG** → the `.dmg`

Both attach to the same **GitHub Release**. The Mac is built on a GitHub-hosted macOS runner — you do not need a Mac.

✅ **Check:** GitHub → Releases → `v1.0.6` has **both** files attached.

## Step 6 — Install and smoke test

Download the installer from the Release, install it on the till, and run [POS_ONSITE_CHECKLIST.md](POS_ONSITE_CHECKLIST.md).

⚠️ **The installer's compiled default endpoint is Dev** (`100.114.12.38`, Tailscale) — a customer machine cannot route to it. Pick **Test** on the master-login screen, or build with:

```powershell
flutter build windows --dart-define=API_BASE_URL=https://51-91-6-6.sslip.io/api
```

---

## If something goes wrong

**Tag was wrong / build failed:**

```powershell
git tag -d v1.0.6
git push --delete origin v1.0.6
# fix, then run tools/release.ps1 again
```

**Deploy broke the Test server:** revert on `test` and push — the deploy re-runs.

```powershell
git checkout test
git revert <bad-commit>
git push origin test
```

**Migration went wrong:** there is no automatic rollback. Restore the database backup, or write a down-migration. Use `-ScriptOnly` first next time.

---

## Rules that are easy to forget

1. **`main` deploys nothing.** Merging to `main` alone changes nothing on the server. You must merge into `test`.
2. **Never `dotnet run`/restart the API from a script while it is under the VS debugger** — build only, then restart it yourself.
3. **The DB step is manual and runs on the server**, never from your PC.
4. **`tools/release.ps1` refuses a dirty tree.** Commit first.
5. **Version only goes up.** The build number is derived for Android and the Play Store rejects a decrease.
6. **Real DB credentials live only in `appsettings.Local.json`** (git-ignored) and in the deployed `web.config`. Never commit them.
