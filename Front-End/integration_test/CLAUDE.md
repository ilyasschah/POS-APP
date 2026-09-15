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
