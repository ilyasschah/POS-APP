# Project Overview
This is an enterprise-grade Point of Sale (POS) ecosystem designed for Windows touch-screen monitors AND 13-inch Android tablets. 
It consists of a C# .NET backend API, a cross-platform Flutter POS frontend, and a Kitchen Display System (KDS).

## 📂 Workspace Folder Structure
This repository contains three main directories. **You must ensure you are in the correct directory before executing any terminal commands (like `dotnet run` or `flutter pub get`).**
* `/Front-End` -> The main Flutter POS application (compiled to .exe and .apk). Uses Riverpod and Dio.
* `/Back-End` -> The C# .NET 8/9 API. Uses Entity Framework Core, SQL Server, and MediatR (CQRS).
* `/kitchen_display` -> The companion frontend application for the kitchen staff to view and manage incoming orders.

---

## 🚫 STRICT BACKEND RULES (CRITICAL)
1.  **NEVER modify Entity Framework Domain Models** (e.g., `PosOrder.cs`, `PosOrderItem.cs`) to add transient/frontend-only data (like `WarehouseId` or UI state).
2.  **Use DTOs for Data Transfer:** Transient data required for business logic (like checking inventory before saving) MUST be passed via Request DTOs (e.g., `CreatePosOrderRequest`) and parsed in the Controllers/Command Handlers.
3.  **Do Not Create Migrations unless explicitly told to.** Do not alter the database schema to solve a UI or logic problem.
4.  **Graceful API Errors:** Business logic failures (like "Out of Stock") must return a `400 Bad Request` with a structured JSON payload: `{ success: false, message: "...", fallbackWarehouses: [...], failedProductId: 123 }`. Do not throw unhandled 500 exceptions for business logic.

---

## 🚫 STRICT FRONTEND RULES (CRITICAL)
1.  **Cross-Platform Compatibility:** The `/Front-End` app must compile for both Windows and Android. If adding new hardware features (like printers or scanners), use packages that support both platforms or cleanly abstract the platform-specific code. 
2.  **10-inch Tablet Responsiveness:** Design UI elements for touch. Buttons and dropdowns must be easily tappable by fingers. Use `LayoutBuilder` and `MediaQuery` to ensure the layout scales beautifully across 10-inch landscape screens without RenderFlex overflows.
3.  **100% Dark Mode Compatibility:** NEVER use hardcoded colors like `Colors.white`, `Colors.black`, or `Colors.grey[100]`. 
4.  **Theme Sourcing:** Always use Material 3 theme properties:
    * Main backgrounds: `Theme.of(context).scaffoldBackgroundColor`
    * Cards/Dialogs: `Theme.of(context).cardColor` or `Theme.of(context).colorScheme.surface`
    * Table Headers: `WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest)`
5.  **"Ilyass Style" (say it and this is the contract):** the house layout
    rules — full spec in `PROJECT_DOCUMENTATION.md` §7 and `handoff.md` §0.
    * **No dead flex space:** never `Expanded(label) + Flexible(value)` — that
      strands the value at the midpoint. Use loose `Flexible` on both sides with
      `MainAxisAlignment.spaceBetween` and flex caps (3/2).
    * **Math-based wrapping:** grids/filter rows compute their own column count
      from `constraints.maxWidth` and a `minTileWidth`, never from
      `context.isCompact`.
    * **Max-width caps:** reading views are wrapped in `Center` +
      `ConstrainedBox(maxWidth: kMaxReadableWidth)` (`lib/core/responsive.dart`).
      Data tables are the exception — they scroll horizontally instead.
    * **Tables:** use `IlyassTable<T>` (`lib/core/ilyass_table.dart`) — draggable
      columns, surplus width to one `flexible` column, `numeric: true` (money,
      counts) end-aligned, actions fixed-width and `resizable: false`.

6.  **"Ilyass Screen" (say it and this is the contract):** the shape of a
    NAVIGATION DESTINATION — `IlyassScreen` in `lib/core/ilyass_screen.dart`,
    full spec in `PROJECT_DOCUMENTATION.md` §7.5 and `handoff.md` §0.5.
    * **A sidebar destination is a TAB, never a pushed route.** Add a `PosTab`
      index + a `screens` entry in `lib/navigation/main_layout.dart` (indices are
      append-only). A pushed one stacks on top of the shell it belongs to.
      Management is the exception — it is a shell of its own.
    * **Never write `leading:` by hand.** `IlyassLeading` decides from the
      MOUNTING: hamburger when hosted with an `onMenuPressed`, nothing when
      hosted without one, back arrow only when actually pushed.
    * 🚨 **Hosted-ness is NOT `Navigator.canPop()`** — both shells are pushed
      over login, so `canPop()` is true inside every tab. The shells wrap their
      stack in `IlyassShell`; that is what the check reads.
    * **No "leave" button.** Cancel cancels the *work*. To hand control back
      after a commit use `ilyassLeave(context, onReturnToShell: ...)` — a bare
      `Navigator.pop()` from a tab pops the shell and signs the cashier out.

7.  **API Client Handling:** When using Dio, catch `400 Bad Request` errors safely and return the JSON response `e.response?.data` to the UI instead of throwing a fatal exception, so the UI can show interactive dialogs.

---

## 🧠 Core Business Logic to Remember
* **Inventory Reservation (Delta Logic):** When updating an existing order, calculate the *Delta* (`IncomingQuantity - OldQuantity`). Only deduct the difference to prevent double-deduction. If the user removes an item, add the quantity back to stock. Skip inventory checks for products marked as "Services".
* **Item-Level Sourcing (Split Sourcing):** Warehouse allocation happens at the *Item Level*, not the global cart level. A single cart can have Product A from Warehouse A, and Product B from Warehouse B.
* **All Products vs Stock:** The Stock/Inventory UI must always list *ALL* products. If a product does not have a stock record in a warehouse, display it as "Unassigned" and provide an option to add it.

---

## State Management Notes
* The Flutter frontends rely heavily on Riverpod (`FutureProvider`, `StateProvider`). Ensure state invalidation (`ref.invalidate(...)`) is called after successful POST/PATCH/DELETE API calls to keep the UI fresh without network reloading.
---

## 🧪 STRICT INTEGRATION TEST RULES (CRITICAL)

**"Modular Test Helpers with Smart Defaults" (say it and this is the contract).**
Flutter integration tests are RECIPES, not scripts. Full spec in
`Front-End/integration_test/README.md` §"The modular pattern".

1. **One flow, one file.** Every major action gets its own file in
   `Front-End/integration_test/helpers/` — `login_helper.dart`,
   `create_tax_helper.dart`, `create_group_helper.dart`,
   `create_product_helper.dart`, `verify_persisted_helper.dart`. There is no
   `test_helpers.dart` grab-bag, and there must never be one. Shared
   *primitives* (`waitFor`, `pickDropdown`, `fillField`) stay in
   `support/e2e_support.dart` — that is a different layer, not an exception.

2. **The test file reads like a recipe.** It defines its data in an
   `E2EContext`, then calls the steps. No UI taps in a `testWidgets` block:

   ```dart
   final ctx = E2EContext();
   await loginToCompany(tester, ctx);
   await createTax(tester, ctx);
   await createProduct(tester, ctx);
   ```

3. **Helpers navigate themselves** (`ensureManagementSection`), so they can be
   mixed and matched in any order. Prerequisites are assumed, not re-run:
   `createProduct` assumes `loginToCompany` already happened.

4. **Smart defaults — the "Index 0" rule.** Every dependency resolves in three
   levels: the explicit argument → what this run created (`ctx`) → the UI's
   first available option. A test that only cares about product creation calls
   `createProduct(tester, ctx)` and takes the catalogue as found.

   🚨 **"First available" is NEVER `items[0]`.** Category, Primary Tax Rate and
   Parent Folder are all built as a null-valued placeholder followed by the real
   rows — literal index 0 is `None (Uncategorized)`, `No Tax`, `None (Root)`.
   Use `pickDropdownAt`, which filters on each item's **value**, never on its
   text (that text is localised). Picking a placeholder by accident ships an
   uncategorized, untaxed product and a GREEN run — the exact bug this codebase
   already shipped once.

5. **The existing guardrails still apply inside helpers**, without exception:
   `waitFor`/`waitUntil` never `pumpAndSettle`; `ctx.l` re-read after every
   navigation, never a hardcoded UI string; every finder scoped to its dialog or
   its open menu, never the whole screen.

   🚨 **The locale is NOT stable at sign-in.** The terminal renders the PIN
   screen in its cached language and the company's `Application.Language`
   arrives with the post-sign-in sync — so the app can be French at the PIN pad
   and English two screens later. `loginToCompany` waits it out with
   `waitForStableLocale`; helpers must still re-read `ctx.l` on the screen they
   are driving, immediately before using its labels. Prefer an untranslated
   handle to a translated one where the app offers one — Quick Settings is found
   by `Icons.tune`, never by its tooltip.

   Pinning the language is a ONE-TIME job — `set_language_helper.dart` and
   `set_language_test.dart` — never part of signing in. It writes the COMPANY's
   setting, so it changes every terminal on that company and the owner dashboard.

6. **A helper that writes data ends up in SQL Server.** `verifyPersisted` proves
   the server ISSUED the id (offline-first rows hold a negative temp id until the
   push swaps it), and writes `e2e/output/e2e-run-manifest.json` carrying the
   query that reads the row's real columns back. An assertion that can pass for
   the wrong reason is worse than no assertion.
