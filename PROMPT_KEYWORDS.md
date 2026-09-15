# 🔑 Prompt Keywords — Octopus POS

Pick keywords from the sections below and paste them into your prompt.

**Formula:** `WHERE` + `WHAT to change` + `CONTRACT` + `TOOL` + `CHECK` + `STYLE`

```text
Front-End > Stock screen: add a warehouse filter.
Ilyass Style + Ilyass Screen. dark mode safe.
check with dart analyze + hot reload. short answer.
```

---

## 1. 📍 WHERE — name the app

| Keyword | What it is |
|---|---|
| `Front-End` | Flutter POS — Windows `.exe` + Android tablet `.apk` |
| `Back-End` | C# .NET API — EF Core, SQL Server, MediatR (CQRS) |
| `kitchen_display` / `KDS` | Kitchen screen app — offline, LAN-paired to the POS |
| `octopus_dashboard_web` | Owner dashboard — Flutter web / PWA |
| `Octopus_Dashboard` | Owner dashboard — iOS app + widget |
| `website` | Next.js marketing + help site (non-standard Next.js — Claude reads its docs first) |
| `integration_test` | Flutter POS integration tests (numbered chain `01_…` → `15_…`) |
| `e2e` | Cypress tests — Admin Portal + Owner Dashboard, against the real dev DB |

---

## 2. 📜 CONTRACTS — say the name, Claude applies every rule

| Keyword | What it enforces |
|---|---|
| `Ilyass Style` | No dead flex space · math-based wrapping · max-width caps · `IlyassTable` |
| `Ilyass Screen` | Sidebar screen = **tab**, never a pushed route · `IlyassLeading` · no "leave" button · `ilyassLeave` |
| `Modular Test Helpers with Smart Defaults` | Tests read like recipes · one helper per flow · "Index 0" rule · `verifyPersisted` |
| `dark mode safe` | Zero hardcoded colors — theme colors only |
| `touch-friendly` / `10-inch tablet` | Big tap targets · `LayoutBuilder` · no RenderFlex overflow |
| `Windows + Android compatible` | Packages must work on both, or be cleanly abstracted |
| `IlyassTable` · `IlyassDropdown` · `IlyassForm` · `IlyassListScaffold` | Use the house widgets in `lib/core/` |
| `app_date_picker` | The unified date picker — never raw Material pickers |
| `ref.invalidate` | Refresh providers after every save/delete |
| `offline-first (Drift)` | Write local first, sync to server later |
| `device-scoped setting` | Per-terminal pref (printer, COM port, backup path) — not cloud settings |
| `Delta logic` | Updating an order deducts only the quantity **difference** |
| `split sourcing` | Warehouse is picked per **item**, not per cart |
| `show all products / Unassigned` | Stock UI lists every product, even with no stock record |
| `DTO only` | Never add transient data to EF domain models |
| `400 structured error` | `{ success: false, message, fallbackWarehouses, failedProductId }` |
| `fixed tax ignores discounts` | Locked rule: fixed tax = rate × quantity |

---

## 3. 🛡️ GUARDRAILS — control what Claude is allowed to do

| Keyword | Effect |
|---|---|
| `plan first` | Claude plans, you approve, then it codes (or press **Shift+Tab** for plan mode) |
| `just do it` | No questions, go straight to the change |
| `ask me if unclear` | Claude asks before guessing |
| `create a migration` | Only way Claude will touch the DB schema (default = no migration) |
| `build only, I restart the API` | Default — Claude never kills/restarts the running API |
| `read-only SQL` | Queries only, no INSERT/UPDATE/DELETE |
| `don't commit` / `commit when done` / `open a PR` | Git behaviour |
| `don't touch other files` | Keep the diff small |
| `ask me before deleting` | Confirmation before removing anything |

---

## 4. 🎯 I WANT TO… → keywords to add

### Build or change a screen (Flutter UI)
`Ilyass Style` · `Ilyass Screen` · `dark mode safe` · `touch-friendly` · `IlyassTable` · `hot reload` · `dart analyze` · `/frontend-design` *(fresh, polished look)*

### Add or change an API endpoint
`Back-End` · `CQRS command` / `CQRS query` · `DTO only` · `400 structured error` · `no migration` · `build only` · `/security-review`

### Look at or fix data
`pos-mssql` *(server SQL Server)* · `pos-sqlite` *(this PC's local POS database)* · `read-only SQL` · `show me the SQL first`
> ⚠️ Never ask Claude to "test a wrong DB password" — it locks `pos_app_user` and takes the API down.

### Find and fix a bug
`/debug` · `reproduce first` · `root cause, not a patch` · `get runtime errors` *(dart)* · `check the row in pos-mssql` · `widget inspector`

### Write or run tests
`Modular Test Helpers with Smart Defaults` · `verifyPersisted` · `TEST_PLAN.md` · `/testing-strategy` · `e2e Cypress` *(dashboards / admin portal)*

### Review or clean up code
`/code-review` · `/code-review high --fix` *(apply fixes)* · `/code-review 123 --comment` *(post on PR #123)* · `/simplify` · `/security-review` · `/tech-debt`

### Plan a feature or architecture
`plan first` · `/system-design` · `/architecture` *(decision record / ADR)* · `/testing-strategy`

### Design — Figma, UX, accessibility
`Figma` + paste the figma.com link · `Figma to Flutter` · `push this screen to Figma` · `/design-critique` · `/design-handoff` · `/accessibility-review` · `/ux-copy` *(labels, error messages, empty states)* · `/design-system`

### Website (Next.js)
`website` · `open it in Chrome and check` · `take a screenshot` · `read console errors` · `/run`

### Printers, scanners, hardware
`printer` · `LAN 9100` / `Bluetooth` / `USB ESC/POS` · `device-scoped setting` · `Windows + Android compatible` · `build apk (JDK 21)`

### Docs and notes
`/documentation` · `update PROJECT_DOCUMENTATION.md` · `update handoff.md` · `save it to Notion` · `/process-doc` · `/runbook`

### Release, deploy, on-site install
`RELEASE_RUNBOOK.md` · `/deploy-checklist` · `/change-request` · `SERVER_SETUP.md` · `POS_ONSITE_CHECKLIST.md`

### Field problems and reporting
`POS_FIELD_ISSUES.md` · `/incident-response` · `/status-report` · `/standup`

### Make a shareable page, chart or diagram
`make an artifact` *(web page with a link)* · `dashboard` · `chart` · `diagram`

### GitHub
`github` · `open a PR` · `list my open issues` · `review PR #123`

### Repeat or schedule work
`/loop 5m <task>` *(repeat in this session)* · `/schedule` *(cloud job on a timer)*

### Claude Code itself
`/doctor` *(health check)* · `/mcp` *(connectors on/off)* · `/context` *(what fills memory)* · `/compact` · `/model` · `/update-config` *(settings, hooks, permissions)* · `/fewer-permission-prompts` · `/keybindings-help`

---

## 5. 🧰 ALL SKILLS (slash commands)

**Engineering plugin** — `/architecture` · `/code-review` · `/debug` · `/deploy-checklist` · `/documentation` · `/incident-response` · `/standup` · `/system-design` · `/tech-debt` · `/testing-strategy`

**Design plugin** — `/accessibility-review` · `/design-critique` · `/design-handoff` · `/design-system` · `/research-synthesis` · `/user-research` · `/ux-copy`

**Operations plugin** — `/capacity-plan` · `/change-request` · `/compliance-tracking` · `/process-doc` · `/process-optimization` · `/risk-assessment` · `/runbook` · `/status-report` · `/vendor-review`

**Frontend plugin** — `/frontend-design`

**Built-in** — `/code-review` *(low · medium · high · max · ultra, `--fix`, `--comment`)* · `/simplify` · `/security-review` · `/run` · `/loop` · `/schedule` · `/doctor` · `/init` · `/update-config` · `/fewer-permission-prompts` · `/keybindings-help` · `dataviz` · `artifact`

---

## 6. 🔌 CONNECTORS (MCP) — say the name to use it

| Keyword | Connects to | Use it for |
|---|---|---|
| `pos-mssql` | SQL Server (server DB) | Query/check real server rows, find tables/columns |
| `pos-sqlite` | `pos_app.sqlite` on this PC | Inspect the POS app's local offline database |
| `dart` | Dart/Flutter tools | `dart analyze` · `hot reload` · `hot restart` · `get runtime errors` · `widget inspector` · `pub` |
| `github` | GitHub | PRs, issues, branches, code search |
| `Figma` | Figma | Design → code and code → design |
| `Notion` | Notion | Save plans, specs, notes as pages |
| `Chrome` | Your Chrome browser | Click through pages, screenshots, console logs, GIF recordings |
| `IDE` | VS Code | Current errors/warnings in open files |

**Turned off** (turn back on with `/mcp`): `context7` *(library docs)* · claude.ai `Gmail` · `Google Calendar` · `Google Drive` · `Microsoft 365` · `Notion` (claude.ai copy)

---

## 7. 💬 ANSWER STYLE

`short answer` · `steps only` · `explain why` · `give me 2–3 options` · `show the diff` · `Ilyass = …` *(label what I must do myself)*

---

## 8. 💤 Skills turned off by /doctor (2026-09-15)

`banner-design` · `brand` · `canvas-design` · `design` · `design-system` (user copy) · `find-skills` · `slides` · `ui-styling` · `ui-ux-pro-max`

To use one again, say: `re-enable skill <name>`

---

## 9. ✍️ Ready-made prompts

```text
Front-End: turn the Cash In/Out page into an Ilyass Screen. Ilyass Style. dark mode safe. hot reload when done. short answer.
```

```text
Back-End: add an endpoint to transfer stock between warehouses. CQRS command, DTO only, 400 structured error, no migration. build only.
```

```text
Bug: refund doesn't return stock. /debug, reproduce first, check the rows in pos-mssql (read-only SQL). root cause, not a patch.
```

```text
integration_test: add a test for creating a discount. Modular Test Helpers with Smart Defaults. verifyPersisted.
```

```text
/code-review high --fix on my current changes, then open a PR.
```

```text
website: open the help page in Chrome, check mobile width and console errors, take a screenshot.
```
