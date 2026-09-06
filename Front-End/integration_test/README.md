# Front-End integration tests

The suite is a **numbered chain** — each test leaves the state the next one
needs, which is why the files sort into their run order.

| # | Test | Network | What it proves |
|---|---|---|---|
| 01 | `01_login_new_company_test.dart` | **real** — boots `main()`, every request goes out | Device registration, onboarding, PIN, licensing. **The only one that spends a seat.** |
| 02 | `02_set_language_test.dart` | **real** — never re-registers | One-time: pins this terminal's UI language |
| 03 | `03_setup_catalog_test.dart` | **real** — never re-registers | Groups, tax, products (one in `kg`), barcodes — and records the catalogue to `pos-credentials.json` |
| 04 | `04_setup_stock_test.dart` | **real** — never re-registers | Warehouse assignment and reorder rules, read back from that catalogue |
| 05 | `05_setup_modifiers_test.dart` | **real** — never re-registers | Modifier groups in both shapes: optional-many and required-one |
| 06 | `06_make_sale_retail_test.dart` | **real** — never re-registers | The money path for a counter shop, **sold by scanning** |
| 07 | `07_create_customer_test.dart` | **real** — never re-registers | A real customer, recorded to `pos-credentials.json` for the credit and loyalty paths |
| 08 | `08_create_warehouse_test.dart` | **real** — never re-registers | A second stock location, so item-level sourcing has somewhere to split to |
| 09 | `09_create_payment_types_test.dart` | **real** — never re-registers | Card, Voucher and a credit Account type (`markAsPaid: false`) |
| 10 | `10_create_users_test.dart` | **real** — never re-registers | An admin AND a cashier, each given a device PIN, recorded with their credentials |
| 11 | `11_security_rules_test.dart` | **real** — never re-registers | Locks Settings + Management, then signs in as each user: admin passes, cashier is refused |
| 12 | `12_void_reasons_test.dart` | **real** — never re-registers | The reason list the void dialog offers, with ranks |
| 13 | `13_barcode_rules_test.dart` | **real** — never re-registers | A weight (21) and a price (23) format beside the seeded four, checked with the editor's own matcher |

Not part of the chain:

| Test | What it proves |
|---|---|
| `smart_defaults_test.dart` | The "Index 0" rule against the real app |
| `clear_local_data_test.dart` | Utility: wipes this terminal's saved identity |
| `cipher_test.dart` | Local database encryption |

The full map of every test this ecosystem needs — retail, restaurant, KDS,
offline, hardware — is in [`TEST_PLAN.md`](../../TEST_PLAN.md) at the repo root.

A bare `flutter test` collects none of them — `integration_test/` is only reached
with an explicit path and a device.

---

## The modular pattern

Tests written from here on are **recipes**, not scripts. The flow lives in a
helper file; the test file says which steps to run and with what data.

```dart
testWidgets('catalog', (tester) async {
  final ctx = E2EContext();

  await loginToCompany(tester, ctx);
  await createTax(tester, ctx);
  await createProduct(tester, ctx);
});
```

That is the same shape as the Cypress suite this pattern was lifted from — a
spec that builds a `context` object and hands it to `Login(context)` and
`CreateLotArrivage(context)`, with every flow in its own module file.

### The layers

| | lives in | holds |
|---|---|---|
| **Primitives** | `support/e2e_support.dart` | `waitFor`, `pickDropdown`, `fillField`, `searchList` — the vocabulary |
| **Flows** | `helpers/<action>_helper.dart` | one action each: log in, create a tax, create a product |
| **Recipes** | `*_test.dart` | data + the sequence of flows |

🚨 **One flow per file. There is no `test_helpers.dart` and there must never be
one** — that grab-bag is what the split exists to prevent. Primitives staying
together in `e2e_support.dart` is not an exception to that: they are a
vocabulary, not flows, and nothing in them drives a screen.

```
helpers/
  e2e_context.dart              the context object + the resolution rule
  login_helper.dart             loginToCompany
  set_language_helper.dart      setTerminalLanguage (one-time setup)
  create_tax_helper.dart        createTax
  create_group_helper.dart      createProductGroup
  create_product_helper.dart    createProduct
  add_barcode_helper.dart       addBarcode
  create_customer_helper.dart   createCustomer
  create_warehouse_helper.dart  createWarehouse
  create_payment_type_helper.dart  createPaymentType
  create_user_helper.dart       createUser
  security_rule_helper.dart     setSecurityLevel
  record_users_helper.dart      recordE2EUser, loadE2EUsers
  reset_user_pin_helper.dart    setUserDevicePin
  switch_user_helper.dart       logoutFromTill, signInAsUser
  guarded_access_helper.dart    expectGuardedScreen
  create_void_reason_helper.dart createVoidReason
  barcode_rule_helper.dart      addBarcodeRule, testBarcodeMatch
  open_register_helper.dart     ensureRegisterOpen, ensureTablelessAllowed
  make_sale_helper.dart         makeSale
  verify_product_helper.dart    verifyProduct        (the UI's answer)
  verify_sale_helper.dart       verifySaleBanked, verifySaleOnServer
  verify_persisted_helper.dart  verifyPersisted      (the database's answer)
```

`setup_catalog` and `make_sale` are both written this way. Between them they are
about 250 lines; the flow they drive is 1,300 and is shared.

### Helpers navigate themselves

Each one calls `ensureManagementSection`, so it works whether it was called
straight after `loginToCompany` (the till is on screen) or straight after
another helper (already inside Management, on a different section). That is what
makes them mix-and-matchable in any order.

Prerequisites are **assumed, not re-run**: `createProduct` takes it for granted
that `loginToCompany` has happened. Chaining is the test file's job.

🚨 "Am I in Management?" is answered by the presence of `Exit Management`, which
exists only in that rail — **not** by `Navigator.canPop()`. Both shells are
pushed over login, so `canPop()` is true inside every tab of either one. The
"Ilyass Screen" contract in `CLAUDE.md` calls that out as the trap it is.

### Smart defaults — the "Index 0" rule

A test that only wants to prove product creation should not have to build a tax
and a group first. Every dependency therefore resolves in three levels:

1. **The explicit argument** — `createProduct(taxName: 'Reduced 7%')`. The test
   is asserting a specific relationship, so nothing may override it.
2. **The context** — whatever an earlier helper in this run recorded, so
   `createTax()` → `createProduct()` links up unasked.
3. **The UI's first real option** — nothing named, nothing built, so take what
   the company already has.

Each helper **prints which level it used**, because silently taking a different
one is the failure this ordering exists to prevent:

```
▶ Group: "Hot Drinks [E2E 09061412]" (created by this run)
▶ Tax: "VAT 20% [E2E 09061412] (20.0%)" (first available — nothing was named)
```

#### 🚨 "First available" is NEVER `items[0]`

Every one of these dropdowns is built as a null-valued **placeholder** followed
by the real rows:

```dart
items: [
  DropdownMenuItem(value: null, child: Text(l10n.noTax)),   // <- index 0
  ...enabled.map((t) => DropdownMenuItem(value: t.id, ...)),
]
```

So the literal index 0 is:

| dropdown | `items[0]` |
|---|---|
| Category / Group | **None (Uncategorized)** |
| Primary Tax Rate | **No Tax** |
| Parent Folder | **None (Root)** |

A helper defaulting to index 0 would create an **uncategorized, untaxed product
and report success** — which is not a hypothetical. `ProductGroupId NULL` and a
price overwritten by the markup recalc are both bugs this suite has already
shipped green, and both are in the list below.

`pickDropdownAt` filters on each item's **value**, never on its text. Text would
work in English and quietly select an untaxed product on a French terminal —
the same language trap everything else here is built around. When a company has
no real option at all, it **fails** with "the smart default needs at least one
row to exist already" rather than falling through to the placeholder.

The filter has its own unit test — `test/dropdown_smart_default_test.dart`,
which runs without a device.

### The locale is not stable at sign-in

🚨 The terminal renders the PIN screen in whatever language it had **cached**,
and the company's real `Application.Language` arrives with the post-sign-in
sync. So the app can be French at the PIN pad and English two screens later,
with nothing wrong with it.

A helper that read `ctx.l` once at sign-in and reused it therefore hunts for
French labels on an English screen:

```
No dropdown labelled "Langue"
  On screen now: General | Order & Payment | ... | ENGLISH | Language | ...
```

`loginToCompany` closes that window with `waitForStableLocale`, which requires
the same locale on three consecutive polls rather than sleeping a fixed amount —
a fast sync costs nothing and a slow one is still caught. It prints the flip when
it happens:

```
▶ Locale changed mid-run: fr -> en (the company setting arrived)
▶ Till language settled: en
```

Two rules follow, and they apply to every helper:

* **Re-read `ctx.l` immediately before using its labels**, on the screen being
  driven — not once per test, and never across a navigation.
* **Never reach for a control by a translated string when an untranslated handle
  exists.** Quick Settings is found by `Icons.tune`, not by its tooltip, because
  a stale `ctx.l` breaks the tooltip lookup one step earlier — where it looks
  like a missing button rather than a stale language.

The race has a unit test of its own: `test/locale_settle_test.dart`, which flips
a real widget tree's locale mid-run and needs no device.

### Pinning the language is a one-time job

`setTerminalLanguage` lives in its own helper and its own test, and is
deliberately NOT part of signing in. It writes the **company's**
`Application.Language`, so it changes the language for every terminal on that
company and for the owner dashboard — a real change, not a per-test convenience.

It is also not a prerequisite for anything. The helpers never hardcode a UI
string; they read `ctx.l` and follow whatever language the app is in. Pin it once
for a human watching the run:

```bash
flutter test integration_test/set_language_test.dart -d windows
```

### Guardrails still apply inside helpers

Extracting a flow does not relax anything. Inside a helper file:

* `waitFor` / `waitUntil`, **never** `pumpAndSettle` — an indeterminate spinner
  schedules frames forever, so it times out on a screen that is working.
* `ctx.l`, re-read after every navigation, **never** a hardcoded UI string. The
  locale can change mid-run.
* Every finder scoped to its dialog or its open menu, never the whole screen.

### Verifying against SQL Server

`verifyPersisted` closes every recipe that writes data, and does two things.

**In the app** — it waits for each row to carry a **positive** id and
`syncStatus == 'synced'`. These screens are offline-first: a row is written
locally under a temporary negative id and the push swaps in the id the server
assigned, so `id > 0` is proof the server stored it. Asserting that *before* a
sync would only assert that the sync had already happened, which is why the
recipe calls `syncNow` first.

**In SQL Server** — it writes `e2e/output/e2e-run-manifest.json` carrying what
the run created and the query that reads those rows' real columns back:

```json
{
  "runTag": "09061412",
  "artifacts": [{ "table": "Product", "name": "Espresso [E2E 09061412]",
                  "expected": { "Price": 18.0, "Group": "Hot Drinks [E2E 09061412]" } }],
  "verificationSql": ["SELECT p.Id, p.Name, p.Price, p.ProductGroupId, ..."]
}
```

That second half is the one that catches a well-formed row with wrong contents —
the price mangled by the recalc, the `ProductGroupId NULL` — because the sync
accepts both of those happily.

🚨 The generated SQL escapes the run tag as `[[]E2E 09061412]`. In T-SQL square
brackets open a **character class**, so `LIKE '%[E2E 09061412]%'` reads "any one
of the characters E, 2, space, 0, 9, 1, 4, 6" and matches almost every row in the
table — verified against the live database, where `'Zebra'` matches it. A
verification query built the naive way returns the whole catalogue and passes no
matter what the run wrote: the "assertion that can pass for the wrong reason",
reintroduced inside the checker itself.

---

## login_new_company

The first-install journey, end to end, against the **real** dev server and the
**real** database:

```
wipe this device → master login (Dev) → onboarding → PIN → MainLayout
```

It is the second half of a loop that starts in Cypress. `e2e/` provisions a
company through the admin portal and writes its login to
`e2e/output/pos-credentials.json`; this test picks up the newest entry and
proves a till can actually use it.

### Run it

```bash
cd e2e && npm run test:company     # once, to create a company
cd ../Front-End
flutter test integration_test/login_new_company_test.dart -d windows
```

The app opens in a real window and every step is visible. Each step prints:

```
▶ Company 36 — Beer, Blanda and Jones [E2E 09051935]
▶ Local device identity wiped — this is now an unregistered terminal
▶ Device id pinned to POS-e2e-login-new-company (re-uses one seat)
▶ Master login reached
▶ Registered. Onboarding started (language: fr)
▶ POS name: POS1
▶ POS screen open — login_new_company PASSED
```

### Static data

`config/test_config.dart` — the Flutter twin of `e2e/config/test-config.js`.
POS name, PIN, theme, accent, environment, which company to use.

🚨 Unlike the Cypress config this file **is committed**, deliberately: it holds
no secrets. The one real credential in this flow is the company password, and
that is read at run time from `e2e/output/pos-credentials.json`, which is
git-ignored. Keep it that way — if a test ever needs a real password, it goes in
that file, never in this one.

### It leaves state behind

The run registers this machine as a terminal of that company. It also **wipes
whatever terminal identity this machine already had**, so don't run it on a
machine being used as a real till. To undo:

```bash
flutter test integration_test/clear_local_data_test.dart -d windows
```

---

## Four things that will bite you writing tests like this

**1 · The app is not always in English.** It ships en/fr/ar and picks its locale
from the company's `Application.Language`. A test written against `'Next'` fails
on a French terminal with "Suivante" on screen and nothing wrong with the app —
and the language can *change mid-run*: this flow starts in `en` at master login
and is in `fr` by onboarding, because the setting arrives during registration.
So every finder reads `l10nOf(tester)`, re-read after each navigation, never a
hardcoded string.

**2 · `pumpAndSettle` cannot be used.** It waits for the tree to go idle, and
this flow is never idle when it matters: the login button holds a
`CircularProgressIndicator` while it talks to the server. An indeterminate
spinner schedules a frame forever, so `pumpAndSettle` times out on a screen that
is working perfectly. `waitFor` pumps on an interval and tests a finder instead.

**3 · Never count onboarding slides.** The controls bar sits below the PageView,
so "Next" is on *every* slide — waiting for it tells you nothing about which
page you are on. And the data-source slide advances itself when you choose the
cloud, so a fixed tap count overshoots by one. (It did: an earlier version
sailed past Setup and landed on Layout.) `advanceUntil` taps until the
destination is actually visible.

**4 · Repeat runs are where the traps are.** Two of them, both fixed and both
invisible on a first run:

- **Seats.** Wiping the device clears `device_id`, so the app mints a new
  `POS-<uuid>` — and the server enforces the seat cap at master login. Every run
  would burn a seat, and a 3-seat company would fail the fourth run with "that
  limit is reached", looking like a regression. `kDeviceId` pins the identity so
  re-runs re-register the *same* terminal.
- **The PIN pad has two modes.** The first run *creates* the PIN (four digits,
  then four more to confirm). But `setDevicePin` stores it against this user and
  this device — and the device is now pinned, so the next run opens the pad in
  *verify* mode and wants the PIN once. A test that always typed eight digits
  would send the last four into an already-authenticated screen. The test
  branches on which heading the pad shows.

---

## When a finder misses

`waitFor`, `tapVisible` and `advanceUntil` all print **what was on screen** in
the failure, because a Flutter finder otherwise reports only what it wanted:

```
Timed out after 60s waiting for: widgets with text "Créer un PIN à 4 chiffres"
  On screen now: Beer, Blanda and Jones | America Lind | Administrateur |
                 Saisir le PIN | 1 | 2 | 3 | ...
```

That line is what turned "No element" into "the app is in French" and "the pad
is in verify mode" in a single run each.

---

## setup_catalog

🚨 **The flow now lives in `helpers/`.** This section explains WHY each step is
the way it is; the code that does it is in the helper named beside the step. If
you are changing behaviour, change the helper — every other recipe shares it.


Signs in to the terminal **as it already is** and builds a catalogue through the
real UI:

```
PIN → Settings (language → English) → Management →
  Product Groups (a parent folder + a child of it)
  Tax rates (20%)
  Products (normal · service · sold by weight), each carrying that tax
    → sync → a generated EAN-13 each → sync again → verify it all persisted
```

The tax is created **before** the products because the products use it. Each one
is saved with the 20% rate attached, and the final pass reopens every product
after a second sync to prove the tax, the group, the price and the barcode all
came back from the server.

```bash
flutter test integration_test/setup_catalog_test.dart -d windows
```

🚨 **It never registers a device, so it never spends a seat.** That is the whole
reason it exists as a separate test: `login_new_company` has to wipe and
re-register to prove the first-install path, and registration is the one action
that consumes a licence. This one starts from a linked terminal, so run it as
often as you like. It fails with a clear message if the terminal is not linked
yet.

Static data lives in `config/test_config.dart` alongside the rest:
`kLanguageCode`, `kTaxRatePercent`, `kParentGroupName`, `kChildGroupName`,
`kDisplayRank`. Names and codes get a per-run tag (`[E2E 09052238]`, `V09052238`)
so a row traces back to the run that made it — and so re-runs don't collide with
`UQ_Tax_Code_PerCompany`.

### Two things it does NOT do, and why

**No group or product image.** The "Choose Image" button calls
`ImagePicker().pickImage`, which opens the *operating system's* file dialog — a
window outside the Flutter tree that a widget test cannot see or click. A colour
is set instead, which is the same field's alternative in the UI.

**No barcode during creation.** Creating a product is a two-phase dialog, and
phase 2 (Taxes / Barcodes / Modifiers) only opens for a product that already
reached the server. A new one is `pending_create` with no server id, so a
"saved locally, sync first" snackbar appears instead — a barcode has nothing to
attach to yet. The test does what an operator would: creates all three, runs a
manual **Sync now**, then reopens each product and adds the barcode in edit mode.
A barcode is then still `isPendingSync`, so the test syncs a **second** time and
reopens each product to check the code is listed *and no longer pending* — that
is the difference between "the app accepted it" and "the server has it".

---

## make_sale

🚨 **The flow now lives in `helpers/`.** This section explains WHY each step is
the way it is; the code that does it is in the helper named beside the step. If
you are changing behaviour, change the helper — every other recipe shares it.


The money path. Signs in to the linked terminal, sells the first thing in the
catalogue, and then proves where that sale actually went:

```
PIN → open the register → first product GROUP → first PRODUCT in it → PAY
    → verify in local SQLite → sync → verify on the SERVER
```

```bash
flutter test integration_test/make_sale_test.dart -d windows
```

A passing run reads:

```
▶ Company 36 — Beer, Blanda and Jones [E2E 09051935]
▶ Linked company confirmed: Beer, Blanda and Jones [E2E 09051935]
▶ Selling as America Lind
▶ Register trading (gate: allowed)
▶ Group opened: Beverages [E2E 09052155]
▶ Product: Table Service [E2E 09052155] @ 25.0
▶ Cart: 1.0 × Table Service [E2E 09052155] = 25.0
▶ Paying with Espèces
▶ Tendered 25 for 25.0
▶ Saved locally — document POS1-200-000001 for 25.0
▶ Sync complete
▶ Server accepted it as document 189
▶ make_sale PASSED — sold for 25.0, local POS1-200-000001 = server 189
```

It is the last act of the loop, and each act needs the one before it:

| | writes | so that |
|---|---|---|
| `e2e` (Cypress) | `pos-credentials.json` | there is a company |
| `login_new_company` | the device registration | the terminal is linked to it |
| `setup_catalog` | groups, tax, products | there is something to sell |
| `make_sale` | one real sale | — |

Like `setup_catalog` it **never registers a device**, so it never spends a seat.

### When the newest company is not the linked one

This is the normal state of a busy machine, not an error: a terminal is linked to
whichever company registered it **last**, and any Cypress run provisions a newer
one without touching this device. The test checks for it on the PIN screen and
says so:

```
This terminal is linked to company 36 (Beer, Blanda and Jones [E2E 09051935]),
but the newest entry in pos-credentials.json is 37 (Hegmann and Sons [E2E 09052305]).
```

🚨 That check is deliberately made **before** the user-card wait, and the reason
is worth keeping. The PIN screen of the *wrong* company is a perfectly healthy
screen — it just lists that company's users — so without the check the mismatch
surfaces 90 seconds later as `No card for "Jordon Quitzon"`, which reads like a
broken user list rather than a terminal pointed somewhere else.

Two ways out, and they are not equivalent:

- **Relink** — `flutter test integration_test/login_new_company_test.dart -d
  windows`. Spends a seat, and the new company has an empty catalogue, so
  `setup_catalog` has to run against it before there is anything to sell.
- **Pin** — set `kCompanyId` in `config/test_config.dart` to the linked company.
  Free and instant, but it is shared config: `login_new_company` and
  `setup_catalog` read the same constant, so put it back to `null` afterwards.

### What "saved correctly" is checked to mean

**Locally** — the `documents` row that was not there a moment ago carries the
grand total the cashier was shown, a local document number, and the open
session's id; its one `document_items` row carries the product, quantity and
unit price from the cart; its `payments` row carries the total (not the tender —
change is not money the shop took).

**Online** — after a manual sync, the local row has a `serverId` and reads
`synced`, and `GET /Document/GetAll` returns that id with the *same* total and
the *same* number. The last one matters: the device issues the number offline
and BatchSync keeps it rather than generating its own, so a receipt in the
customer's hand matches the record even for a sale rung up with no network.

### Four things it has to do before it can sell at all

**Open the register.** `sessionGateProvider` blocks the whole till behind
`SessionBlockedScreen` — no search field, no cards, nothing to tap — until a
session is open. The test opens one (float 0.00) when there isn't one, and stops
with a clear message when the drawer is live on *another* terminal, because that
one has to be joined rather than opened over.

**Allow tableless orders.** `Order.AllowTablelessOrders` ships **false** with the
floor plan on, and at those defaults a tap on a product does not ring it up — it
says "select a table from the floor plan" and returns. The test flips it through
the app's own settings notifier (there is no override seam: this boots the real
`main()`), which does change that company's setting. One more reason not to
point this at a real till.

**Find something that is actually sellable.** The browser renders
`[...visibleGroups, ...visibleProducts]`, so inside any folder the sub-folders
come *before* the products — a catalogue shaped like Beverages → Hot Drinks →
Espresso, exactly what `setup_catalog` builds, has nothing sellable on the first
screen. The test walks the tree depth-first in that same order, which is the
order a finger takes, and prints every folder it opens.

🚨 It does **not** stop at the first folder, and that is deliberate rather than a
loosening of "sell the first product". Folders here are *usually* empty: every
`setup_catalog` run leaves its groups behind, so a company accumulates them —
company 36 had 30 groups and its first-ranked one held nothing at all. Giving up
there would go red over one stale row, having proved nothing about the money
path. A cashier who reads "This folder is empty" backs out and taps the next
one; so does this.

Which product is "first" is the *company's* answer, not the test's: it reads
`Products.Sorting` and applies `sortProductsBy`, the same call the grid makes.
On company 36 that setting is `Code`, which is why the run below sells Table
Service rather than the alphabetically-earlier Loose Coffee Beans.

**Answer whatever the product asks.** A tap is not always one tap: an age
restriction, a weight, a quantity or a price can each stand between the tap and
the cart line, and `setup_catalog`'s products trip several (it stamps an age
restriction on every one, and one of the three is sold by weight). With no scale
configured — every Android tablet, and any Windows till that has not set one up —
`showWeighItemDialog` skips its own dialog and goes straight to the keypad, so
both shapes are handled. The test drives what is **on screen** rather than
predicting from the product's flags, so a change in the order the app asks fails
as an obvious timeout rather than a mysterious one.

### Two races it is written around

**Do not assert `syncStatus == 'pending'` after a checkout.** Checkout fires a
background sync on its way out, so the row can legitimately be `synced` before
the next line runs — that assertion would fail on a *fast* network, for the best
possible reason. Assert the content, which does not move.

**Do not read `allPaymentTypesProvider` before the checkout dialog is up.** It is
`autoDispose` and the dialog is its only listener on this screen, so an earlier
read starts the stream, gets `AsyncLoading`, and reports a company with no
payment types at all.

`waitUntil` in `support/e2e_support.dart` is the primitive for both: `waitFor`
watches the widget tree, `waitUntil` polls a fact that is not on screen at all —
a Drift row, a server id stamped by a sync that finishes seconds later.

---

## setup_modifiers

Builds modifier groups through Management, in **both shapes the till can
render**:

```
PIN → Management → Modifier Groups → create two groups
    → verify in local SQLite → sync → verify on the SERVER
```

```bash
flutter test integration_test/setup_modifiers_test.dart -d windows
```

### Why two scenarios and not one

A group's min/max pair is not decoration — it is the **only** thing deciding the
control the cashier is handed, so the two shapes are genuinely different
features:

| | rule | control | behaviour |
|---|---|---|---|
| `Extras` | min 0 / max 3 | checkboxes | take none, take three; free text on |
| `Cup Size` | min 1 / max 1 | radios | the sale is **blocked** until one is chosen |

`Cup Size` also carries a **negative** surcharge (`Small`, −2.00) — legitimate,
and the reason the price field lets a minus sign through at all.

### Four things it has to get right

**A new group's id is NEGATIVE.** `modifier_groups.id` is "positive = server id,
negative = temp local id". A group saved offline holds a temp id until the push
swaps it, so asserting `id > 0` before the sync would just be asserting that the
sync had already happened. The test checks content locally, syncs, and only then
requires a positive id.

**The push RE-KEYS the row.** `remapModifierGroupId` deletes the negative row and
writes a new one under the server's id, so after the sync the group has to be
found **by name** again. A test holding the old id is looking for a row that no
longer exists.

**The editor is a pushed page, not a dialog** — a group and its options go to
`/Modifiers/SaveGroup` in one transaction, so the form is too long to hide in a
dialog. That matters to the finders: the list screen behind is still in the tree,
and its FAB carries the *same label* as the save button ("Add Modifier Group").
They are told apart by **widget** — `FloatingActionButton` vs `FilledButton` —
never by text.

**A hint does NOT disappear when you type into the field.** The option rows are
identical widgets with identical hints, so the obvious way to tell row 2 from
row 1 is "the one still showing its hint". That reasoning is wrong, and it fails
silently: Flutter's `InputDecorator` keeps the hint `Text` **mounted** and merely
fades it to zero opacity, so `find.widgetWithText(TextField, hint)` matches every
row whether it has text in it or not — and `.first` is always row 0.

The first version of this test did exactly that. Three option names were typed
one over another into the same box, the group saved with a single choice named
after the *last* one, and nothing failed until an assertion three steps later
reported one option where three were expected. Rows are addressed by
**position** (`.at(row)`) instead, which is stable however the fields are
filled.

### One stale comment it turned up

`_NumberField` in `lib/modifier/modifier_groups_screen.dart` documents itself as
"Typed entry as well as the arrows: setting 'pick up to 6' by tapping + six times
is the kind of thing that makes an admin screen hated" — but the widget it
describes has only `-`, a `Text`, and `+`. There is no field to type into. The
test steps the arrows because that is all there is; the comment is describing an
intention, not the code.

---

## create_customer

Creates a **real** customer through Management and records it where the rest of
the suite can find it.

```
PIN → Management → Customers & Suppliers → new customer
    → verify locally → verify on the SERVER → write it to the credentials files
```

```bash
flutter test integration_test/create_customer_test.dart -d windows
```

### Why the walk-in is not enough

Every sale these tests ring up goes to the walk-in customer, code `C000` — and
for testing purposes that is not a customer at all:

- **Credit is unreachable.** The checkout blocks any payment type with
  `isCustomerRequired` and rejects `C000` *by name*, so a credit/tab sale cannot
  be tested with it.
- **No discount profile**, so the customer-discount path is dead.
- **No loyalty card**, so points can be neither earned nor redeemed.

### Online-first — unlike the rest of Management

🚨 Creating a customer does **not** use the offline-first flow the catalogue
screens use. The form writes an optimistic row under a negative temp id, POSTs to
`/Customer/AddCustomercommand` immediately, then swaps the temp row for one keyed
by the server's id and marks it `synced` — all before the dialog closes. There is
no sync step.

That is why the test asserts the id is **positive**, not merely that a row
exists: the offline path leaves the negative temp row in place and says "saved
offline, will sync", so "there is a customer row" is also true for a customer the
server has never heard of.

### Where it gets written

```jsonc
// e2e/output/pos-credentials.json — nested under the company it belongs to
{
  "companyId": 36,
  "companyName": "Beer, Blanda and Jones [E2E 09051935]",
  // …
  "customers": [
    { "createdAtUtc": "…", "customerId": 81, "name": "Fatima Zahra [E2E 09060056]",
      "code": "C09060056", "email": "…", "phone": "…" }
  ]
}
```

🚨 **The JSON is the durable record; the `.txt` is a convenience view.** Cypress
*rewrites* `pos-credentials.txt` from scratch on every provisioning run
(`saveCredentials` renders it from `history[0]`), so the customer block there
survives only until the next company is provisioned. The block is delimited by
`=== E2E CUSTOMERS ===` markers so a re-run replaces it rather than stacking, and
nothing outside those markers is touched.

It also carries a warning that earns its place: the summary at the top of that
file describes the newest company **Cypress** created, which is usually *not* the
company the customer belongs to — the terminal is linked to whichever company
`login_new_company` last registered against.

### Using it in a later test

```dart
final customer = await loadE2ECustomer();   // newest, for the linked company
```

It throws with "run create_customer_test first" rather than returning null, so a
test that depends on a real customer fails where the problem is.

---

## Six more traps this suite already fell into

Every one of these passed on the first run and failed later, which is the
expensive kind.

**1 · `find.byType` and generics.** `DropdownButtonFormField` is generic —
`<int?>` for a group, `<String>` for a setting — and `find.byType` compares the
*exact* runtime type, so `find.byType(DropdownButtonFormField<Object?>)` matches
nothing at all. Quietly. Use `anyDropdownField` (a name-based predicate).

**2 · Two shapes of "labelled dropdown".** Tax and settings put the caption in
the field's own `labelText`, so the Text really is *inside* the dropdown. The
group editor prints a section label **above** a dropdown whose decoration is
null — a sibling, which no ancestor search will ever reach. `pickDropdown` takes
a `within:` scope for that case.

**3 · Lists only build what is on screen.** A freshly created row lands below the
fold of a scrollable table and `find.text` cannot see it — the row exists, the
database has it, the test fails anyway. It gets worse every run, because these
tests leave their rows behind. `searchList` filters to the row under test. The
same applies *inside* an open dropdown menu, which is why `pickDropdown` scrolls
its menu before giving up on an option.

**4 · A missed tap can close the dialog you are filling in.** `showDialog` is
barrier-dismissible by default, so a tap at an off-screen widget's coordinates
lands on the barrier and dismisses the editor. The test then fails several steps
later looking for a field on a form that is no longer there, pointing nowhere
near the tap that caused it. Scroll before tapping; never silence a miss.

**5 · The same label can exist twice.** While the group list is empty the screen
behind carries its own "Create Group" button, so an unscoped finder matches two
— and the first in tree order is the one *underneath* the modal barrier. Scope
dialog controls to the dialog.

**6 · A session belongs to a REGISTER, not to a device.** `activeSessionProvider`
matches a session row's `posDeviceUid` against **`registerUidProvider`** — which
reads the `PosSession.RegisterUid` setting and, when that is blank, falls back to
the machine's real device GUID out of secure storage. It is *not*
`deviceUidProvider`.

Get this wrong and the symptom points nowhere near the cause: the seeded session
belongs to a register the test is not working, `sessionGateProvider` reads
`blockedNoSession`, the browser renders `SessionBlockedScreen`, and the search
field and product grid are simply **not on screen** — so the failure arrives as
"no product card", several steps later.

Two consequences, one per kind of test:

- Seeding a session row (a mocked till test) means also setting
  `SettingKeys.registerUid` to the same uid — through the shipping settings
  provider, which keeps the test off secure storage, whose value differs on every
  machine.
- Driving the real app (`make_sale`) means never inferring the register state
  from the screen. `_ensureRegisterOpen` reads `sessionGateProvider` directly and
  waits for it to stop saying `unknown`, because `unknown` deliberately *renders
  the grid* — a till that cannot answer must never be the reason a shop stops
  trading — so "no blocked screen on this frame" is very often "the gate has not
  decided yet".

### A note on the 0.773px overflow

Driving these forms raises a transient `RenderFlex overflowed by 0.773 pixels`
from inside a `TextField`'s `InputDecorator`, against an element that is already
`DEFUNCT`. It is invisible on screen, and it fails the whole test because
flutter_test treats any framework error as a failure. `setup_catalog` therefore
ignores overflows **under 2px only** — a real one, the kind CLAUDE.md forbids,
is tens or hundreds of pixels and still fails loudly.

---

## Three bugs the database found that the run output did not

All three produced a completely green run. They were caught by querying SQL
Server afterwards, which is the argument for doing that at least once whenever a
test starts writing new kinds of data.

**1 · The price was the cost.** `Products.CostPriceBasedMarkup` is seeded
**true**, which wires a listener recomputing the selling price from
`cost x markup` whenever the cost field changes. Filling price-then-cost threw
the price away: a product entered at 18 with a cost of 6 reached the database
priced at **6**. Two of three products looked right, because the recalc guards on
`cost > 0` and the service's cost was `0` — which is exactly the kind of partial
symptom that makes a bug look like a fluke. Fix: fill **cost first, price
second**, and assert both.

**2 · One product had no group at all.** Reproducibly the third, with
`ProductGroupId NULL`. The dropdown tap was missing its menu entry — and
`tester.tap` does **not** fail on a missed hit-test, it prints a warning and
carries on. Fix: `pickDropdown` now verifies the selection stuck and retries.

**3 · The verification that should have caught #2 was itself wrong.** It checked
`find.textContaining(groupName)` against the whole screen — and the products
table *behind* the dialog has a Category column showing those same group names.
So it matched a row belonging to a previously created product and passed while
the dropdown had not changed at all. Fix: every dropdown read-back is scoped to
the dropdown, and every option search is scoped to the open menu.

The pattern in all three: **an assertion that can pass for the wrong reason is
worse than no assertion**, because it converts a silent data bug into a green
test. Scope finders to the widget you mean, and verify against the database once.
