# Responsiveness Plan — 7″ tablets + French text fit

_Drafted: 2026-07-25._

> **Target device:** 7″ tablet, **1920×1200** physical, landscape. At a typical
> OEM density (devicePixelRatio ~1.5–2.0) Flutter lays this out at roughly
> **960–1280 dp wide × 600–800 dp tall** — much tighter than the 10–13″ the app
> was built for. **Plus:** French UI text runs ~15–20 % longer than English, so
> anything not flexed/ellipsised overflows.

---

## 1. What's already responsive (don't touch)

The shell is structurally sound and will **not** hard-overflow on a small screen:

- **Nav drawer** is an *overlay* (slides over content), and `NavItem` labels are
  `Expanded` + `maxLines:1` + ellipsis — French truncates, never overflows.
- **POS product grid** sizes via `LayoutBuilder` from the configured cols/rows.
- **Cart panel** and **product-group sidebar** are user-resizable and the content
  beside them is `Expanded`, so a fixed panel just shrinks the neighbour.
- **POS header action buttons** live in a horizontal `SingleChildScrollView`.
- **Settings sidebar** already measures the active locale's longest label with a
  `TextPainter` and clamps its width (the French "Save & Restart" fix).

So the job is **density + leaf-level overflow**, not a shell rewrite.

## 2. Shared foundation (added)

`Front-End/lib/core/responsive.dart` — one set of breakpoints for the whole app:

| Helper | Meaning |
|---|---|
| `context.isCompact` | width < 1000 dp — a 7"-class tablet; tighten spacing, prefer icon-only chrome |
| `context.isVeryCompact` | width < 760 dp — most aggressive density |
| `context.isShort` | height < 680 dp — tall dialogs must scroll |
| `context.dialogWidth(preferred)` | caps a fixed dialog width to the viewport |
| `context.dialogMaxHeight()` | caps a dialog/body height on short screens |

## 3. The fix patterns (apply per screen)

1. **Un-flexed text in a `Row`** → wrap in `Expanded`/`Flexible` + `maxLines:1` +
   `TextOverflow.ellipsis`. This is the #1 French-overflow cause.
2. **Icon + label buttons** → cap the label width and rely on a tooltip for the
   full text (done for the POS header buttons in `_MenuActionVisual`).
3. **Fixed-width dialogs** (`width: 500`, `420`, `380`…) → `context.dialogWidth(500)`.
4. **Tall dialogs** → wrap the body in a scroll view + `context.dialogMaxHeight()`.
5. **Data tables** → ensure the table sits in a horizontal `SingleChildScrollView`
   (or `DataTable` inside one) so wide French headers scroll instead of overflow.
6. **Fixed `fontSize` in dense rows** → let it inherit, or step down on `isCompact`.

## 4. Prioritised batches (highest-traffic first)

| # | Area | Files |
|---|---|---|
| 1 | POS menu header + cart panel | `menu/menu_screen.dart` ✅ header labels capped |
| 2 | Checkout + payment dialogs | `cart/payment_checkout_dialog.dart`, `menu/quantity_keypad_dialog.dart`, `menu/discount_dialog.dart` |
| 3 | Management data tables | `product/products_screen.dart`, `document/documents_screen.dart`, `stock/stock_screen.dart`, `product/customers_screen.dart`, `reports/sales_history_screen.dart` |
| 4 | Floor plan / tables + bookings | `floor_plan/*`, `bookings/*` |
| 5 | Reports + Z-report + dashboard | `reports/*`, `dashboard/dashboard_screen.dart` |
| 6 | Remaining dialogs / pickers | app-wide sweep of `width:` literals |

## 5. How we verify (important)

**Layout overflow is invisible to `dart analyze` and to the test suite** — it only
shows when rendered. I don't have the 7″ device; **you do**. The fastest, most
accurate loop:

1. Run the app on the 7″ tablet **in French**.
2. Screenshot every spot that overflows (yellow/black stripes) or truncates badly.
3. Send them — I fix those exact widgets in a batch, then you re-check.

This targets the real breakage instead of blind-editing ~197 files. Batch 1
(POS header) is done as a first, safe pass; the rest are ordered above.

## 6. Optional: a widget test that catches French overflow

For the worst offenders we can add a `test/` that pumps the screen at 960×600
for each `AppLocalizations.supportedLocales` and asserts **no RenderFlex
overflow** — the same technique that pinned the settings-sidebar French fix.
Worth doing for checkout + the main tables once we know which ones break.

## 7. Progress log

### ✅ Fixed (verified from device screenshots, French)
- **PIN pad** — height-aware scale so the numpad fits a short screen (`login_screen.dart`).
- **POS header** — order-control buttons now sit in the width-bounded AppBar `title` slot as a **horizontal scroll** (`SingleChildScrollView`), so they scroll instead of running off-screen; company name dropped from the header (`menu_screen.dart`). ⚠️ **Do NOT put an overflow menu (`MenuAnchor` *or* a `LayoutBuilder`-based `OverflowActionsBar`) in the AppBar title** — both crashed with `_dependents.isEmpty` (red screen) whenever the header rebuilt (e.g. renaming the POS while Settings is open above the still-mounted MenuScreen). The plain horizontal scroll is the stable replacement. A true "show hidden buttons" drawer would need a different, device-tested approach.
- **Cart footer** — "ANNULER"/"PAYER" labels scale to one line (`menu_screen.dart`).
- **Discount dialog** — tighter insets + scrollable body (`discount_dialog.dart`).
- **Stock table** — horizontal scroll for wide FR columns (`stock_screen.dart`).
- **Stock detail `_infoRow`** — label+value flex so long values wrap (`stock_screen.dart`).
- **Reports list header** — title flexes/ellipsizes, search tightened to 200 (`reports_screen.dart`).
- **Promotions table** — Actions cell wrapped in `FittedBox` scale-down (`promotions_list_screen.dart`).
- **Tax-rate edit dialog** — `scrollable: true` + tighter insets (`tax_rates_screen.dart`).
- **Sales history toolbar** — action group scrolls horizontally inside `Expanded`; Columns/Refresh pinned right (`sales_history_screen.dart`).
- **Credit payments form** — left form panel wrapped in `SingleChildScrollView` (`credit_payment_screen.dart`).

### ⏳ Pending
_None outstanding from the captured screenshots. Test the above on the device and send any new overflow spots._
