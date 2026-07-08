# Payment Checkout Dialog — Figma Handoff

**Figma file:** https://www.figma.com/design/sKP8EKp7DoD9fnNVOwYi4L
**Source of truth (code):** `Front-End/lib/cart/payment_checkout_dialog.dart`
**Target devices:** Windows touch monitors + 13" Android tablets (landscape). Buttons must stay finger-tappable.

---

## 1. Overall layout

A full-screen modal `Dialog`, ~1400 × 760, corner radius 16, dark surface. Three columns left→right:

| Column | Width | Contents |
|--------|-------|----------|
| **Order Summary** | 280 fixed | Header · scrollable item list · Subtotal/Total footer |
| **Payment Method** | 230 fixed | Header · payment-type buttons · outlined "Split Payments" |
| **Numpad & Totals** | fills rest | Customer bar · Total/Paid/Change · numpad grid |

Columns separated by 1px vertical dividers (`outline` token).

---

## 2. Color tokens (Figma `Theme` collection, dark mode)

Bind to these variables — **do not hardcode hex** (project rule: 100% dark-mode + theming).

| Token | Hex | Used for |
|-------|-----|----------|
| `accent` | `#5B8DEF` | Selected payment chip, Total value, customer name, Split button outline/text. **Single source for the whole accent color.** |
| `accent/on` | `#FFFFFF` | Text/icon on accent fills |
| `surface` | `#161618` | Dialog background |
| `surface/container` | `#1E1F22` | Column headers, customer bar, summary footer |
| `surface/high` | `#2A2C30` | Numpad keys, unselected payment buttons |
| `text/primary` | `#E6E7EA` | Main text |
| `text/muted` | `#9A9CA3` | Subtitles, Change row, disabled Complete label |
| `outline` | `#34363B` | Dividers, borders |
| `error/container` | `#B3221F` | Numpad ⌫ and C keys |
| `error/on` | `#FFFFFF` | Text/icon on red keys |
| `success` | `#2E7D32` | Complete Transaction (when enabled) |

**Cancel** text uses red `#E5534B` (error accent).

---

## 3. Accent color toggle (image-2 picker)

The app has a settings "Accent Color" picker with 14 swatches. In Figma, **everything accent-colored is bound to the one `accent` variable** — changing that variable recolors the entire dialog at once.

> Note: a true dropdown/mode toggle (one mode per color) needs a **paid Figma plan** — the free Starter plan caps a collection at 1 mode. On a paid plan, convert `accent` to 14 modes named below.

Swatch palette (selected one gets a 2px ring + check):

| Name | Hex | Name | Hex |
|------|-----|------|-----|
| Blue | `#3B82F6` | Violet | `#8B5CF6` |
| Sky | `#0EA5E9` | Purple | `#A855F7` |
| Indigo | `#4F46E5` | Pink | `#EC4899` |
| Green | `#22C55E` | Rose | `#F43F5E` |
| Teal | `#14B8A6` | Orange | `#F97316` |
| Emerald | `#10B981` | Red | `#EF4444` |
|  |  | Amber | `#F59E0B` |
|  |  | Deep Orange | `#FF5722` |

---

## 4. Built in Figma so far ✅

- Wrapper frame + 3 columns wired to tokens
- Order Summary (header, item row, Subtotal/Total footer)
- Payment Method (cash2 selected, Espèce, Crédit, Cash, Split Payments)
- Customer bar (Walk-in Customer + Cancel) and Total/Paid/Change totals

## 5. Still to add 🚧 (cut off by Figma free-plan tool limit)

### Numpad (fills remaining height under the totals; 8px gaps, padding 12)
```
Row 1:  7    8    9    ⌫(red)
Row 2:  4    5    6    C(red)
Row 3:  ┌ 1  2  3 ┐    ┌────────────┐
Row 4:  └ 00 0  . ┘    │  Complete  │  ← spans rows 3+4,
                       │ Transaction│    ~210px wide
                       └────────────┘
```
- Number keys: `surface/high` fill, radius 10, centered 22px Medium label.
- ⌫ / C keys: `error/container` fill, `error/on` icon/label.
- Complete Transaction: check-circle icon + 2-line bold label. **Disabled state** = `surface/high` fill + `text/muted` (shown when Paid < Total). **Enabled** = `success` green fill + white.

### Accent color picker strip (from image 2)
Single horizontal row of the 14 swatches above; selected swatch ringed with a check. Place it below the dialog as a reference/legend for the designer.

---

## 6. Things to improve (designer brief)
- Touch targets sized for 13" tablet fingers (no tight spacing).
- Verify contrast of `accent` text on dark surface for every swatch (some light accents like Amber may need `accent/on` = dark).
- Keep all colors token-bound so a single accent swap restyles the whole screen.
