# TASK — Replace the admin portal's shared-secret gate with real user accounts

Paste this whole file as the opening message of a new session. It carries the
context you would otherwise have to rediscover, and the traps that have already
cost time in this repo.

---

## What I want

The admin portal (`/admin`) currently has **no users**. It is gated by a single
shared secret. I want proper accounts:

1. A **users table in the MASTER database** (`web-pos-master`) — the one behind
   the admin portal. Not in `web-pos`; that is tenant data.
2. A **login page** for the portal (username + password form).
3. A **first admin user seeded automatically**: username `Admin`, password
   `Admin@123`.
4. **Each user carries their own token** — no more the old shared-key way.

Keep the portal working throughout. I run the API under the Visual Studio
debugger, so **never kill or restart it** — build, then tell me to restart.

---

## Where things stand today (verified, not guessed)

### The gate you are replacing
`Back-End/Web-POS.Api/Middleware/AdminPortalGate.cs` — one shared secret from
config `AdminPortal:AccessKey`:

- Applies to any path starting `/admin`.
- Entry is `?key=<secret>` once, then it stores the key in an **`admin_portal_key`
  cookie** and redirects to a clean URL.
- Empty key ⇒ **503** on purpose (a blank secret would otherwise admit everyone).
- Compares with `CryptographicOperations.FixedTimeEquals` — keep constant-time
  comparison in whatever replaces it.
- Sets `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`,
  `Cache-Control: no-store` on every `/admin` response. **Keep these.**

Registered in `Program.cs`:
```
app.UseAuthentication();
app.UseAuthorization();
app.UseMiddleware<Api.Middleware.AdminPortalGate>();   // ~line 498
```
and the pages are exempted from the JWT fallback policy:
```
builder.Services.AddRazorPages(options =>
    options.Conventions.AllowAnonymousToFolder("/Admin"));   // ~line 228
```

⚠️ **The API is fail-closed.** `Program.cs` sets an authorization `FallbackPolicy`
of `RequireAuthenticatedUser()`, so every endpoint needs a token unless it is
explicitly anonymous. The whole `/Admin` folder is currently anonymous *because*
`AdminPortalGate` guards it. If you move the portal onto cookie auth, the login
page itself must stay reachable — that is the easiest thing to get wrong here,
and you will lock yourself out of the portal.

### Existing portal pages (Razor Pages)
```
Pages/Admin/Companies/{Index,Create,Edit,Details}.cshtml
Pages/Admin/Subscriptions/Index.cshtml
Pages/Admin/Users/Edit.cshtml
Pages/Shared/_Layout.cshtml      ← renders TempData Success / Warning / Error banners
```

### The Master database — READ THIS BEFORE TOUCHING SCHEMA
`Api.Master.MasterDbContext` — `Tenants`, `Subscriptions`, `Devices`,
`BillingEvents`, `TransactionAudits`. Connection string `MasterConnection`
(`web-pos-master`), registered around `Program.cs:100`.

🚨 **The Master DB has NO EF MIGRATIONS.** Do not run
`dotnet ef migrations add --context ...MasterDbContext` — that is not how this
database is managed. Its schema comes from:

- `docs/sql/master-db-schema.sql` — idempotent `IF OBJECT_ID(...) IS NULL CREATE TABLE`
  blocks, run once by hand, **and**
- a self-healing idempotent `CREATE TABLE` block in `Program.cs` (~line 444) that
  the `TransactionAudit` table uses. It is wrapped in `CanConnect()` +
  try/catch so an absent or unreachable Master DB never blocks boot.

**Follow that existing pattern for the new users table**: add it to
`docs/sql/master-db-schema.sql` *and* add an idempotent bootstrap block so a
machine that has not run the SQL still self-heals. Keep it non-fatal.

(The **tenant** database `web-pos` *does* use EF migrations — do not confuse the
two. Everything in this section is about the master DB only.)

### Password hashing + tokens already in the codebase — reuse, don't reinvent
- **BCrypt** is already a dependency and is how POS user passwords are handled:
  `BCrypt.Net.BCrypt.HashPassword(...)` / `.Verify(...)`
  (see `Queries/AuthQuery/LoginQuery.cs`, `Commands/UserCommands/Update/*`).
  Use BCrypt for the admin users too. **Never store `Admin@123` in plain text.**
- **`Services/TokenService.cs`** already issues the app's JWTs, signed with
  `Jwt:Secret` from configuration.
- ⚠️ `Jwt:Secret` is blank in the committed `appsettings.json`; the real value is
  a user-level env var (`Jwt__Secret`). A startup guard aborts outside
  Development if it is empty, short, or a placeholder. **Rotating it invalidates
  every live POS session** — so do not touch it.

### Migration tooling traps (the tenant DB, if you end up needing it)
- `.config/dotnet-tools.json` pins a **local** `dotnet-ef` **9.0.8** while the
  project is **EF Core 10.0.9**. Use the global tool:
  `~/.dotnet/tools/dotnet-ef.exe`.
- There are **two DbContexts** — every command needs
  `--context Api.DataBase.AppDbContext` or `--context Api.Master.MasterDbContext`.
- 🚨 **`migrations add --no-build` silently emits an EMPTY migration** when the
  built assembly is stale, and reports success. Always read the generated `Up()`.
- 🚨 A full `dotnet build` **fails while the API is running** (`MSB3021`, the exe
  is locked by the debugger). Use **`--configuration Release`** — it builds to
  `bin/Release/`, which the running Debug exe does not lock.
- 🚨 **Apply a migration BEFORE the API restarts.** Adding a property to an EF
  entity changes every SELECT/INSERT for that table the moment the API loads —
  there is no grace period. An unapplied migration turns into
  *"Invalid column name"* on every request. That exact mistake stranded a paid
  sale on 2026-08-06.

---

## What to build

Design it yourself, but it must satisfy all of this:

**Schema** — a users table in `web-pos-master`. At minimum: id, username
(unique), password hash, display name, active flag, created/last-login stamps.
Add a role/permission column **only if** you actually use it; do not add
speculative columns.

**Seeding** — on startup, if the table has **no users**, create `Admin` /
`Admin@123` (BCrypt-hashed). Idempotent: it must never recreate or reset the
account once one exists, and it must never overwrite a changed password. Log
loudly that a default-credential account was created, and force/prompt a change
if you can do it without blocking me from logging in.

**Login page** — a Razor page under `Pages/Admin/` (e.g. `/admin/login`).
Username + password, BCrypt verify, generic failure message (never reveal
whether the username exists), and a logout.

**Per-user token** — replace the shared cookie key. Cookie authentication with
the user's identity is the natural fit for server-rendered Razor Pages; a JWT is
also acceptable if you prefer to reuse `TokenService`. Either way:
- the token identifies **the user**, not "someone who knows the key";
- it expires, and logout invalidates the session;
- keep the constant-time comparison and the security headers from the old gate.

**Retire `AdminPortal:AccessKey`** once the new path works — including the
`AllowAnonymousToFolder("/Admin")` convention, which exists only because the old
middleware was doing the gating. Leave the login page reachable.

---

## House rules for this repo

- **Backend:** CQRS — thin controllers, MediatR handlers for logic, repositories
  for EF. Business failures return **400** with
  `{ success: false, message: "..." }`, never an unhandled 500.
  `Middleware/ExceptionHandlingMiddleware.cs` already maps
  `KeyNotFoundException → 404`, `InvalidOperationException → 400`,
  `UnauthorizedAccessException → 403`.
- **Never restart the API.** Build with
  `dotnet build -t:Compile -v q --nologo`, report, and ask me to restart
  (Ctrl+Shift+F5).
- **Verify, don't assume.** There is a live SQL Server behind the `pos-mssql`
  MCP server — query it to confirm what the schema actually is rather than
  inferring from code. Run the build. Run the tests.
- **Tests** are expected for anything with logic worth pinning (password verify,
  the seed being idempotent, an unauthenticated request being redirected rather
  than served). Test the real behaviour — a test that asserts a hand-written
  constant proves nothing.
- Read `handoff.md` §3 ("The expensive ones", "Backend / EF") before you start.
  It is a list of bugs this repo has already paid for.

---

## Definition of done

1. `web-pos-master` has the users table; the SQL file and the bootstrap block
   both create it, idempotently.
2. Visiting `/admin` while signed out lands on the login page.
3. `Admin` / `Admin@123` signs in and reaches the companies list.
4. Bad credentials fail with a generic message; the account is not enumerable.
5. Logout returns to the login page and the old session no longer works.
6. `?key=` no longer grants access; `AdminPortal:AccessKey` is gone from the code
   path.
7. Security headers still present on `/admin` responses.
8. `dotnet build -t:Compile` → **0 errors**; tests pass.
9. Tell me exactly what to restart and what to run, and flag anything you chose
   not to do.

---

## Open questions — decide and tell me, or ask if it changes the design

- Should admin users be **manageable from the portal** (add/disable/reset), or is
  the seeded `Admin` enough for now? I would rather start small.
- Do you need **roles** yet, or is every admin user equal? Do not build roles I
  have not asked for.
- Session lifetime + "remember me" — pick sensible defaults and state them.
