# End-to-end tests — Admin Portal & Owner Dashboard

Cypress tests that drive the **real** apps against the **real** dev database.
Nothing is stubbed, intercepted or mocked. Every green run leaves a genuine
company, subscription tenant and user behind in `web-pos` / `web-pos-master` —
open SSMS afterwards and the rows are there.

Two apps, one loop:

| Spec | App | What it does |
|---|---|---|
| `admin-portal/01`, `02` | ASP.NET Razor Pages (`Back-End/.../Pages/Admin`) | Provisions a company, subscription, logo and first user |
| `dashboard/03`, `04` | Flutter web, CanvasKit (`octopus_dashboard_web`) | Signs into the Owner Dashboard **as that company** |

The loop continues outside Cypress: **`Front-End/integration_test/login_new_company_test.dart`**
takes the same company out of `output/pos-credentials.json` and walks a brand-new
Windows terminal through master login, onboarding and the PIN to the till. See
[`Front-End/integration_test/README.md`](../Front-End/integration_test/README.md).

The portal half is server-rendered HTML, which is why Cypress fits it: real
forms, real POSTs, real redirects, and the antiforgery token rides along because
the tests click the actual submit button. The dashboard half needs a different
technique entirely — see §8.

---

## 1 · Setup (once)

```bash
cd e2e
npm install
cp config/test-config.example.js config/test-config.js   # already done for you
```

Then **open `config/test-config.js` and fill in the two `FILL_ME` values**:

| Field | What it is |
|---|---|
| `adminUsername` / `adminPassword` | The account you sign in with at `/admin/login`. The seeded default is `Admin` / `Admin@123` (`Admin/AdminUserSeeder.cs`), but the portal nags you to change it — use whatever it actually is now. |
| `baseUrl` | Where the API is running. Defaults to `http://100.114.12.38:5002`, the `http` profile in `launchSettings.json`. |
| `dashboardBaseUrl` | Where the Owner Dashboard is served. Defaults to `http://100.114.12.38:8081`. |
| `subscriptionDays` | `14`, `30`, `90`, `180` or `365` — the Billing Period dropdown offers nothing else. |
| `seatAllowance` | **Your device number**: max terminals allowed to sync. |
| `logoPath` | Absolute path, or relative to `e2e/`. Blank uses the bundled brand icon. |

> 🚨 `config/test-config.js` is **git-ignored** and must stay that way — it holds
> a real admin password and this repository is public. The committed file is
> `test-config.example.js`, which contains no secrets.

Every one of those is validated in Node **before a browser launches**, so a
missing value fails in under a second with a message naming the field — not
with a browser that types `FILL_ME` into the login form and reports "Incorrect
username or password", sending you off to reset a password that was never wrong.

---

## 2 · Run

The API must be running first (`dotnet run` in `Back-End/Web-POS.Api`), and
the Owner Dashboard too if you want the dashboard specs.

```bash
npm test                # everything (portal + dashboard)
npm run test:portal     # admin portal only
npm run test:company    # the provisioning journey only
npm run test:dashboard  # Owner Dashboard only (needs a company to exist first)
npm run open            # interactive runner
```

The dashboard specs sign in as the **newest** company in
`output/pos-credentials.json`, so `npm test` works from cold: it provisions a
company, then signs into the dashboard as that company.

---

## 3 · What you get back

`npm run test:company` writes the generated credentials to:

```
e2e/output/pos-credentials.txt    # the latest run, human-readable
e2e/output/pos-credentials.json   # every run, newest first
```

That file is the handoff to the POS front-end. **The POS app signs in with the
EMAIL, not the username** — `LoginQuery` looks the user up with
`GetByEmailAnyCompanyAsync`, which matches on `Email` across *every* company
with no company scoping. That is also why the generated address carries a
per-run tag: a duplicate email would hand a till the wrong company's user.

`output/` is git-ignored too — it holds plaintext passwords.

---

## 4 · What the tests actually assert

**`01-admin-login.cy.js`** — writes nothing.

- A signed-out request to `/admin/companies` answers **302**, not a 200 login
  page. Asserted with `followRedirect: false`, because following the redirect
  turns "signed out" into a green 200 and proves nothing.
- `/` and `/admin` both redirect to `/admin/companies`. No Razor page lives at
  `/admin`; `Program.cs` maps those two by hand, and without them the request
  matches no endpoint at all.
- A wrong password returns the generic *"Incorrect username or password."* —
  the exact wording is the security behaviour, since naming the reason would
  turn the form into a username oracle.
- A correct sign-in lands on the dashboard with the signed-in chrome rendered.

**`02-provision-company.cy.js`** — the real journey, in order:

1. Fills the Provision form with Faker data, uploads the logo, sets the
   subscription and seats, toggles **Provision Initial User** and fills it in.
2. Follows the redirect to `/admin/companies/details/{id}` and captures the new
   company ID.
3. Reads the profile back off the Details page and compares it to what was typed.
4. Asserts the **Master-DB subscription tenant** exists, with the right days
   left, a future expiry and `0 / {seats}` devices.
5. Fetches the logo bytes back out through the portal's own handler and asserts
   the content type is `image/png` or `image/jpeg`.
6. Asserts the new user's badge reads **Admin**.
7. Asserts the company appears on the dashboard and on Subscriptions with the
   seat allowance read back from the Master DB.
8. Writes `output/pos-credentials.txt`.

Three of those are guarding specific failures this codebase has actually had or
is exposed to, and they are commented as such in the spec:

- **Step 4** — `ProvisionTenantAsync` runs *outside* the company transaction and
  its failure is caught and logged as a warning. A Master-DB outage therefore
  produces a company that was created perfectly and can never license a till.
  The portal is the only place that shows it.
- **Step 5** — `CompanyLogoFile` accepts PNG/JPEG *by magic bytes* only. A WebP
  uploads happily, previews correctly in every browser, and then prints as
  nothing on every receipt. Both the config validator and the test check the
  real format.
- **Step 6** — access level `0` is Admin, `1` is Cashier. This form once offered
  them the other way round and shipped, so every company's first "Admin" was a
  cashier who could not open Management, and the Details page rendered the badge
  the same wrong way and confirmed the lie back to you.

---

## 5 · Test data

Each run stamps a `[E2E MMDD HHMM]` tag into the company name and into the
username/email, so a row in the database traces back to the run that made it.

**Nothing is cleaned up** — that is the point. To remove a company afterwards,
delete it from the portal (which also deprovisions its Master-DB tenant); a
manual `DELETE` from `dbo.Company` would leave the tenant, its subscription and
its device seats orphaned in the control plane.

---

## 6 · Two environment gotchas

**Running from inside VS Code** — VS Code's extension host exports
`ELECTRON_RUN_AS_NODE=1`, and every terminal or agent spawned from it inherits
that. `Cypress.exe` *is* an Electron binary, so with that variable set it starts
as plain Node, does not understand its own arguments, and dies with:

```
Cypress.exe: bad option: --smoke-test
Cypress failed to start. This may be due to a missing library or dependency.
```

which sends you hunting for a system library that is not missing. `npm test`
goes through `scripts/cypress.js`, which deletes the variable for the child
process. Use the npm scripts rather than `npx cypress` and it never comes up.

**npm blocks Cypress's postinstall.** This npm version defers install scripts,
so the binary download may not run and you get the same `--smoke-test` error for
a genuinely different reason. Fix:

```bash
npx cypress install --force
npx cypress verify
```

---

## 7 · Cypress 16 API note

`Cypress.env()` was **removed** in Cypress 16 and split in two:

| Kind | Config key | Read with |
|---|---|---|
| Secrets | `env` | `cy.env(['key']).then(...)` — a command, so tests only |
| Everything else | `expose` | `Cypress.expose('key')` — synchronous, usable at module scope |

Here the admin password is the only thing in `env`; the rest is in `expose`.

---

## 8 · The Owner Dashboard specs (Flutter web)

`03-dashboard-login.cy.js` closes the loop: it signs into the Owner Dashboard
(`octopus_dashboard_web`, Flutter web) as the company the portal just
provisioned, and proves the dashboard comes up scoped to **that** company.

### Why this needs special handling

The dashboard is built with **CanvasKit**, which paints the entire UI into a
`<canvas>`. There is no DOM for a TextField or a button, so nothing can be
selected the ordinary way. Flutter does build a real DOM accessibility tree, but
only **on demand**: it renders a 1x1 `<flt-semantics-placeholder>` and waits for
someone to activate it. `cy.dashboardVisit()` clicks that first — it is what
turns the app into something a browser driver can see.

Three behaviours cost real debugging time and are pinned down in
`cypress/support/commands.js`:

1. **The session is not in a cookie.** `shared_preferences` on web is backed by
   **localStorage**, under keys Flutter prefixes with `flutter.` —
   `flutter.apiToken`, `flutter.companyId`, `flutter.lastEmail`,
   `flutter.apiBaseUrl`. Clearing cookies does nothing; that store is what
   carries the previous user into the next run. It is cleared in `onBeforeLoad`,
   **before the app boots**, because `AuthController.build()` reads it during
   the first frame — clearing afterwards still lets the old session render once.

2. **`aria-label` disappears once a field has content.** An empty field is
   `input[aria-label="Email"]`; type into it and the attribute is gone, because
   the semantic label becomes the value. A retry written against that selector
   fails with *"Expected to find element: input[aria-label=Email]"*. The three
   `<input>` nodes themselves are stable — same elements, same order, never
   replaced — so the fields are addressed by index, with the label used only as
   a first preference.

3. **Flutter drops the first characters.** The text-editing connection attaches
   asynchronously after a field takes focus, and anything sent before that lands
   nowhere: `jarret.toy.09051855@octopus-e2e.test` arrives as `opus-e2e.test`.
   It is a race, so it passes on a cold app and fails on a warm one. `flutterType`
   waits after focusing, then **verifies the value and retypes** if it is short.
   Without that the suite signs in with a truncated email and blames the password.

### The environment picker

`cy.flutterTap('Dev')` is not optional. The app's compiled-in default is
**Production** (`AppConfig.defaultBaseUrl`), so a test that skipped it would sign
in against the live system. Selecting Dev also rewrites the API Base URL field,
so that field never has to be typed.

---

## 9 · About the dashboard being slow to load

Measured with `04-load-time.cy.js`: **~10-11s cold, ~5s warm** to first frame.

That is the **development server**, not the app. Port 8081 is being served by a
`dartvm` process — `flutter run` in debug mode — and in that mode `main.dart.js`
is a **7.7 KB loader** that then pulls hundreds of separate, unminified DDC
module files over separate requests. The round trips are the cost.

The release bundle is a single **3.65 MB** tree-shaken dart2js file, and that is
what production serves: IIS from `C:\inetpub\wwwroot\dashboard`, deployed from
the `prod` branch. **Customers are not affected by this.**

To get the fast path locally, serve the built output instead of `flutter run`:

```bash
cd octopus_dashboard_web
flutter build web --release
cd build/web
python -m http.server 8081 --bind 100.114.12.38
```

Then re-run `npm run test:dashboard` and compare the reported first-frame time.
