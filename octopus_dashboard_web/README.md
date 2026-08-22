# Octopus Owner Dashboard — Flutter Web (PWA)

An installable Progressive Web App companion for the Octopus POS system: sales
analytics, POS session history and drawer reconciliation, product repricing,
stock levels, sales documents, and staff account management. A web-only
re-platform of the SwiftUI iOS app in `../Octopus_Dashboard/`.

Built with Flutter 3.44 · Riverpod 3 · Dio 5 · fl_chart 1.2.

---

## Quick start

```bash
flutter pub get
flutter run -d chrome          # local dev
flutter test                   # 73 tests
flutter analyze                # clean
flutter build web --release    # output in build/web/
```

Sign in with the **Test** environment preset (`https://51-91-6-6.sslip.io/api`),
which is the default.

---

## Deviations from the original spec

The spec was written against an older Flutter. Four things changed; each was
implemented to preserve the spec's *intent*.

### 1. `--web-renderer canvaskit` no longer exists

The flag was removed when the HTML renderer was deleted in Flutter 3.29.
**CanvasKit is now the default renderer**, so the spec's goal (correct,
GPU-accelerated blur on Safari) is satisfied by the plain build command:

```bash
flutter build web --release    # NOT: --web-renderer canvaskit
```

### 2. Flutter's service worker is deprecated and caches nothing

The spec assumed `flutter_service_worker.js` still provided app-shell caching.
As of Flutter 3.35+ it is deprecated and does nothing but unregister itself, so
there would have been **no caching at all** and no fetch handler for Chrome's
installability check.

Two files address this:

- **`web/sw.js`** — a small app-shell service worker: stale-while-revalidate
  for static assets, network-first for the HTML document, and a hard exclusion
  on `/api/` so **API responses are never cached**. That exclusion matters
  because the API is frequently *same-origin* (hosted next to the app on the
  same box), so an origin check alone would not be enough.
- **`web/flutter_bootstrap.js`** — a custom bootstrap that omits
  `serviceWorkerSettings`, stopping Flutter from registering its deprecated
  worker. A scope holds only one registration, so leaving it in would race with
  and clobber ours.

**Update behavior:** the HTML document is fetched network-first, so a redeploy
is seen immediately, while the cached JS bundle is refreshed in the background
and applied on the next launch. A hard refresh applies it at once. Bump
`CACHE_VERSION` in `sw.js` to force-evict old caches.

### 3. Fonts are bundled, not fetched from Google Fonts

The spec suggested `google_fonts`, which downloads fonts at runtime from
`fonts.gstatic.com` — a network dependency on first paint and a visible font
swap, both at odds with "no unstyled-content flashes".

Nunito is bundled instead (`assets/fonts/Nunito.ttf`, 270 KB).

⚠️ **Nunito ships upstream only as a variable font**, and Flutter does *not*
map `TextStyle.fontWeight` onto a variable font's `wght` axis — a style
declaring `FontWeight.bold` alone renders at regular weight. Every weight must
also carry a matching `FontVariation`.

To make that impossible to get wrong, **always build text styles through
`AppText`** (`lib/core/typography.dart`) rather than constructing a raw
`TextStyle`, and use the `.weighted(700)` extension to re-weight an existing
style.

### 4. Backdrop blur is applied only where it is visible

`BackdropFilter` blurs what is painted *behind* it. This design's background is
a literally flat black or white, and blurring a flat color is a visual no-op
that still costs a full-screen GPU pass — the dashboard alone stacks five
cards.

So content cards render as tint + 1px border (identical over a flat base), and
real blur is reserved for surfaces that float *over* scrollable content:
dialogs, bottom sheets, and the sidebar (`GlassCard.overlay`).

The Settings toggle is wired up for real (unlike the inert iOS original):
turning **Liquid Glass Effect** off makes panels flat and opaque and skips all
blurring, and the **Glass Transparency** slider (5–50%) drives the tint alpha.

---

## Known pitfalls, and how they are handled

| Pitfall | Handling |
|---|---|
| Screens going stale until you navigate away and back | `AppShell._refresh()` re-fetches on **every** tab select, not just the first. `IndexedStack` keeps screens alive, so `initState` alone would never re-run. Covered by the "revisiting a tab re-fetches its data" test. |
| Cancelled requests shown as errors | `ApiException.isCancelled` is set for `DioExceptionType.cancel`; `AsyncController.load()` drops those silently. |
| Flash of "no data" before the first fetch | `ScreenState` starts in **loading**, never idle. |
| Refresh failure blanking a populated screen | A failed refresh keeps the existing data and shows a `RefreshErrorBanner`; the full-screen `ErrorView` appears only when there is nothing to show. |
| Partial product updates rejected | `Product.toUpdateJson()` resends the whole record. The base64 `image` blob is never decoded or re-sent. |
| Stock hiding unstocked products | `ProductStock.join()` left-joins stock onto the **full** product list; products with no stock row show as "Unassigned". |
| Locale shifting API dates by a day | `Fmt` pins `en_US` and formats **local** calendar fields (never `toIso8601String()`, which round-trips through UTC). |
| Browser locale breaking currency | `NumberFormat('#,##0.00', 'en_US')` — always `1,234.56 DH`. |
| Wrong endpoint names | `Document` is singular, `DocumentItems` is plural, users list at `GetAllUsers`. Mirrored verbatim in `OctopusApi`, with comments. |
| Off-screen tabs burning frames | `IndexedStack` keeps hidden children *ticking*; `TickerMode` suspends animation for every screen except the visible one. |
| Session times drifting by the viewer's UTC offset | POS sessions are stamped with `DateTime.UtcNow` but come back from EF as `Kind=Unspecified`, i.e. with **no** zone suffix. `Fmt.parseUtcDate` (not `Fmt.parseDate`) appends `Z` before parsing. Covered by the "unzoned timestamps are read as UTC" test. |
| An attendance shift read as a live register | POS session statuses are 10–13; shifts in the same server table use 0/1. `PosSessionState.fromCode` maps anything else to `unknown`, never to a live state. |
| 50 session summaries fetched to fill four visible rows | `/PosSession/History` carries no takings or order count, so each row watches its own `sessionSummaryProvider(id)` and a `SliverList` only builds what is on screen. The family is *not* auto-disposed — scrolling a row back would otherwise re-fetch it — and is invalidated wholesale on refresh. |
| A "live" pulse repainting a page left open all day | The `LiveBeacon` is a static glow, not an animation. An endless repeat would also hang every `pumpAndSettle` in the test suite. |

---

## Deployment

```bash
flutter build web --release
# hosting under a sub-path:
flutter build web --release --base-href /dashboard/
```

`build/web/` is a fully static site — copy it to the box already serving the
API and point IIS/nginx at it.

### Server checklist

1. **CORS** — the web app sends an `Origin` header that the native app never
   did. The backend must allow the hosting origin on `/api/*`. This is the one
   backend-side change the web pivot requires.
2. **Enable gzip/brotli.** `main.dart.js` is 2.9 MB raw but **887 KB gzipped**.
   Serving it uncompressed is the single biggest avoidable slowdown.
3. **Don't cache `index.html`** at the CDN/proxy layer, or redeploys won't be
   picked up.
4. **CanvasKit is loaded from `gstatic.com` by default** (~5.5 MB wasm,
   heavily shared/cached across sites). To serve it from your own box instead —
   for a fully self-contained deployment, or if gstatic is slow for your users:
   ```bash
   flutter build web --release --no-web-resources-cdn
   ```

### Installing as an app

- **Android/Chrome** — "Install app" from the address bar or ⋮ menu.
- **iOS/Safari** — Share → **Add to Home Screen**. Safari ignores
  `manifest.json` for install behavior, so `web/index.html` also carries the
  `apple-mobile-web-app-*` meta tags and `apple-touch-icon` links that make it
  launch full-screen with the right icon instead of as a plain bookmark.

Regenerate icons after changing the source artwork:

```bash
powershell -ExecutionPolicy Bypass -File tool\generate_icons.ps1
```

---

## Gotchas

- **The Dev preset is unreachable from an HTTPS page.**
  `http://100.114.12.38:5002/api` is blocked as mixed content when the app
  itself is served over HTTPS. The login screen detects this exact combination
  and says so inline, because "wrong API URL" is the most common cause of
  "nothing is loading". Dev only works over `flutter run` on localhost.
- **The session is not persisted.** The JWT is held in memory only (matching
  the iOS app), so a browser reload requires signing in again. The API base URL
  *is* remembered. Persisting the token to `localStorage` would survive reloads
  at the cost of XSS exposure — a deliberate, and reversible, call.
- **`companyId` is hardcoded to 25** in `lib/core/constants.dart`. There is no
  company switcher.
- **POS Sessions is read-only, deliberately.** The screen never calls
  Open/ConfirmOpening/Close/ForceClose. A session is opened, counted and closed
  on the register that owns the drawer; closing one from a browser would strand
  a till mid-count. A closed session also shows its **frozen** expected cash
  (what the cashier was held to) and only mentions the live recomputation when
  the two disagree — that gap is money that arrived after the count.
- **Password reset requires an Admin token.** The server enforces a
  `ManagerOnly` policy; a Cashier-level token gets a 403, surfaced as the
  server's own message.

---

## Project layout

```
lib/
  api/          OctopusApi (typed endpoints) + ApiException (error normalization)
  core/         constants, theme/palette, typography, glass, formatters,
                breakpoints, ScreenState, AsyncController
  models/       DashboardData, Product, StockEntry/ProductStock,
                SalesDocument/DocumentLineItem, StaffUser,
                PosSession/PosSessionSummary/PosSessionMethod
  features/
    auth/       AuthController + login screen (environment picker)
    shell/      AppShell — bottom bar / rail / sidebar + refetch-on-visit
    dashboard/  charts, date-range filter, presets
    sessions/   read-only POS session history, live-register strip,
                per-session drawer reconciliation + payment mix
    products/   list + full-record price editor
    stock/      left-joined per-product stock
    documents/  list + pushed detail route with line items
    users/      staff list + admin password reset
    settings/   account, theme, glass controls
  widgets/      shared state views, list panel, page header, search field
web/            manifest, index.html shell, sw.js, custom bootstrap, icons
tool/           generate_icons.ps1
```

### Architecture notes

- **`AsyncController<T>`** (`lib/core/async_controller.dart`) is the base for
  every screen controller. It centralizes loading/refresh/error/cancel handling
  so the rules above hold uniformly rather than per screen.
- **Providers are scoped per screen**, so refreshing Products never rebuilds
  the Dashboard's charts. `apiProvider` watches only `(baseUrl, token)`, so
  transient auth changes don't churn the client.
- **Responsive tiers** live in `lib/core/breakpoints.dart`:
  compact `<600`, medium `600–1024`, expanded `>1024`.

---

## Tests

`flutter test` — 73 tests, no network.

- **`business_rules_test.dart`** — the update payload contract, the stock
  left-join, role/status derivation, POS session lifecycle mapping and UTC
  timestamp parsing, date presets (including year-boundary rollover), currency
  and date formatting.
- **`api_error_test.dart`** — cancellation flagging, server-message extraction
  in both casings, ASP.NET validation errors, HTML-error-page suppression, URL
  normalization, `ScreenState` transitions.
- **`responsive_test.dart`** — renders every screen at 360/390/768/1280/1920
  plus both breakpoint edges (599/600), asserting the right navigation type and
  no layout overflow; verifies refetch-on-revisit against a counting fake, and
  opens a session detail page at both desktop and phone widths.
- **`login_test.dart`** — environment presets rewriting the URL field,
  password toggle, success/failure paths, and the card's width cap at 1920px.

Fakes live in `test/fake_api.dart` and are injected via `apiFactoryProvider`.
