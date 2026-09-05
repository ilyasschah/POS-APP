# DESIGN.md — Octopus POS marketing site

A plain-text design system for AI agents working on this site. Follows the
[Stitch DESIGN.md convention](https://github.com/voltagent/awesome-design-md).
Motion rules follow [Emil Kowalski's design-engineering skill](https://github.com/emilkowalski/skill).

Palette and surfaces are **derived from the product itself** — the dimmed theme in
`Front-End/lib/core/app_theme.dart` — so the site and the POS look like one product.

---

## 1. Visual theme & atmosphere

Serious software for people running a business, not a consumer app. **Light,
precise, and quiet**, so the brand coral does all the talking. The tone is
**operator-grade**: this is a tool that runs the till during a Friday dinner
rush, and the site should feel as dependable as that.

- Light ground by default. The product's own dark navy appears as **ink and as
  one deliberate dark band**, never as the page background.
- Restraint over decoration. Every element earns its place.
- Density over airiness: real numbers, real screens, short sentences.
- Never "playful startup". No gradients-as-personality, no floating 3D blobs.

## 2. Color palette & roles

Derived from the app icon (`Front-End/assets/icon.svg`), so the site and the POS
read as one product. The icon's navy is used as **ink**, not as ground.

| Token | Hex | Contrast on white | Role |
|---|---|---|---|
| `--ground` | `#FFFFFF` | — | Page background |
| `--surface` | `#FDF3F3` | — | Alternating sections |
| `--surface-raised` | `#FFFFFF` | — | Cards, panels |
| `--surface-high` | `#F7EDED` | — | Hover states |
| `--border` | `#F1E6E6` | — | Hairlines, card edges |
| `--accent` | `#A4161A` | **7.75:1** | Shape *and* text — see below |
| `--accent-strong` | `#A4161A` | white on it: **7.75:1** | Filled buttons |
| `--accent-hover` | `#801114` | **10.46:1** | Hover state of those fills |
| `--accent-ink` | `#A4161A` | **7.75:1** | Links, eyebrows, small text |
| `--accent-dim` | `#F2DEDE` | — | Pale tint fills |
| `--text` | `#1A1A2E` | 17.00:1 | Headings — the icon's navy |
| `--text-muted` | `#4A4A5E` | 8.63:1 | Body |
| `--text-faint` | `#686D85` | 5.10:1 | Captions, metadata |

### Why three of the accent tokens are the same colour

The brand is a **blood red**, and it is DARK — 7.75:1 on white. It clears every
bar on its own, so `--accent`, `--accent-strong` and `--accent-ink` converge.

That is the system working, not a shortcut. The split exists because the coral
this replaced measured **3.37:1**: it could carry a border but not a sentence,
so small text needed a darkened partner generated beside it. A seed that starts
above the bar needs no partner. **Keep using the semantic token anyway** — the
picker re-themes from any colour, and the moment someone chooses a light one the
three diverge again.

`--accent-hover` is the exception and must always differ, or a filled button has
no hover state. It is forced apart by a fixed lightness step rather than by a
contrast target, precisely because a contrast target is already satisfied.

The neutrals carry a trace of the accent's hue rather than being grey. On a page
this light, a true grey beside a red reads as a *different* palette; a surface
warmed toward the brand reads as the same one, dimmed. At hue 358 green and blue
land level, so they read as warm off-whites — the previous coral tinted them
faintly magenta.

### The dark band

| Token | Hex | Contrast on `--navy` | Role |
|---|---|---|---|
| `--navy` | `#1A1A2E` | — | The band's ground — the icon's own background |
| `--navy-deep` | `#16213E` | — | Its gradient partner, at the icon's 135° |
| `--on-navy` | `#F4F5FB` | **15.62:1** | Headings and hover states on the band |
| `--on-navy-muted` | `#A9AEC9` | **7.76:1** | Body and links on the band |
| `--on-navy-line` | `#33344F` | — | Hairlines (`--border` is a light-ground token and vanishes here) |

### Runtime theming — the palette is derived, not fixed

The site re-themes live from a single accent (`app/theme.ts`, exposed by the
picker in the Customisable section). This is not a widget bolted on: it is the
page proving the product's own claim, so it has to hold the contrast contract
above **for every colour a visitor can choose**, not just for the brand.

`deriveAccentTokens(seed)` walks the seed's LIGHTNESS down — hue and saturation
are what the operator picked, and scaling RGB channels instead would hand them
back a colour they did not choose — until each token clears its target:

| Token | Target on white | Why that number |
|---|---|---|
| `--accent` | ≥ 3:1 | Even the raw brand colour is floored. A neon yellow border is otherwise invisible |
| `--accent-strong` | ≥ 4.6:1 | 4.5 lands exactly on the bar; the extra tenth survives rounding |
| `--accent-hover` | ≥ 6:1, or a forced step down | Whichever is darker — a dark seed already clears 6:1, so without the step the button loses its hover |
| `--accent-ink` | ≥ 5.5:1 | Small text wants margin over the 4.5 minimum |

Saturation is capped at **0.78** on the way down — a darkened 100%-saturation
colour reads as an error state, not a brand.

**The neutrals follow the accent too.** `--surface`, `--surface-high` and
`--border` are the accent's hue at fixed low saturation and high lightness; the
(S, L) pairs are read off the hand-tuned values, so the brand hue reproduces
`#FDF3F3` exactly and every other hue gets the same relationship to its own
accent. Leaving them pink while the accent went blue was the tell that gave the
whole demo away.

**The brand accent CLEARS the inline properties** rather than setting derived
ones, so it falls back to the hand-tuned scale in `globals.css`. Those values
sit a shade off what the function derives, and if the default overwrote them,
"back to brand" would land on a slightly different red than the page loaded
with — a reset that looks like a bug.

**The seven swatches are the POS's own**, copied from
`Front-End/lib/onboarding/widgets/setup_slide.dart` in the app's order. If that
list changes, change `POS_ACCENTS` too.

### Light-only, deliberately

**This site has no dark variant, and that is a decision rather than an
omission.** A dark mode here would have to be maintained against a palette whose
whole job is to make one coral read correctly on white — the accent's two-token
split (`--accent` for shapes, `--accent-ink` for text) exists *because* the
ground is light, and it dissolves on a dark one, where the raw coral is already
5:1. Supporting both means keeping two contrast arguments true at once for a
five-section marketing page.

The product itself ships six themes; the site advertising it does not need to.
If a dark variant is ever added it goes in at token level — redefine the `:root`
block under `prefers-color-scheme`, never per component.

**Exactly one dark band ships, and it is the footer.** A dark hero would make
this look like the old dark build; a dark footer reads as a close, and quoting
the icon's gradient at the bottom of a light page is what ties the two together.
⚠️ `--accent` is **dark**, so it does NOT work on the navy band — a blood red on
`#1A1A2E` measures about 1.6:1 and disappears. Anything on that band uses the
on-navy scale; the accent stays on the light ground where it belongs.

### 🚨 The one rule that is not negotiable

**Read the semantic token, never a hex.** `--accent-ink` for small text and
links, `--accent-strong` for a fill under white text, `--accent` for shapes.

Today all three resolve to the same blood red, which makes the rule easy to
forget and expensive to break: the picker re-themes from **any** colour a
visitor chooses, and the moment one of them picks something light the three
diverge again and hardcoded copies go silently under the AA bar. The colour that
sat here before — the coral `#FF416C` at 3.37:1 — is exactly that case.

Ratios above are measured, not estimated. Re-measure before changing any of them,
and note that `parseHex`/`contrastOnWhite` in `app/theme.ts` will do it for you.

## 3. Typography

System font stack — no webfont. A font file is a render-blocking network
request on a page whose whole pitch is "works without a network".

| Level | Size / weight | Tracking |
|---|---|---|
| Display (h1) | `clamp(2.5rem, 6vw, 4.5rem)` / **300** | `-0.02em` |
| Section (h2) | `clamp(1.75rem, 3.5vw, 2.75rem)` / **300** | `-0.015em` |
| Card title (h3) | `1.125rem` / 600 | `-0.01em` |
| Body | `1rem` / 400, `line-height: 1.65` | normal |
| Small / label | `0.875rem` / 500 | normal |
| Eyebrow | `0.75rem` / 600, uppercase | `0.12em` |
| Mono | `ui-monospace, "SF Mono", Menlo, monospace` | — |

Hierarchy is **weight-driven, and inverted**: the display heading is *lighter*
(300) than the small uppercase eyebrow beside it (600). Size already separates
them, so making the big thing bold too says the same thing twice.

Tighten tracking as size grows; large type set at normal tracking looks loose.
Arabic neutralises the negative tracking and takes 1.85 leading — Latin display
tracking collides Arabic letterforms.

Cap measure at `--measure` (`65ch`). A full-width card whose body would stop at
the measure and strand the rest of the card empty uses `.card-split` instead:
heading in one column, prose in the other.

## 4. Component styling

**Buttons** — `border-radius: 10px`, `padding: 0.75rem 1.5rem`, weight 500.
- Primary: `--accent` fill, `#fff` text. Hover `--accent-hover`. Active `scale(0.97)`.
- Secondary: transparent, `1px solid --border`. Hover `--surface-high`.
- Every button has an `:active` state. No exceptions.

**Cards** — `--surface-raised`, `1px solid --border`, `border-radius: 14px`,
`padding: 1.75rem`. Hover: border → `--accent-dim`, `translateY(-2px)`. Hover
effects gated behind `@media (hover: hover)`.

**Icon chips** (`.glyph`) — `42px` square, `border-radius: 12px`, holding a
24px glyph. Background `color-mix(--accent 11%, --ground)`, border
`--accent 24%`, icon in `--accent-ink`. On card hover the chip fills with
`--accent-strong` and the glyph turns white.

The tint is mixed against `--ground` rather than left translucent: these chips
appear on both `--ground` and `--surface` sections, and a transparent tint would
shift shade between the two.

**Nav** — sticky, `backdrop-filter: blur(12px)`, background at 80% alpha,
bottom hairline that fades in only once the page has scrolled past 8px. At rest
the header floats on the page ground with no rule at all.

**Focus** — `2px solid --accent`, `outline-offset: 2px`. Never removed.

## 4b. Iconography

Every feature and every platform carries a glyph. Nine unlabelled cards in a
grid are a wall of text; nine glyphs give the eye somewhere to land and make the
grid scannable at a glance.

**The set lives in `app/components/Glyph.tsx`** — hand-drawn, one file, no icon
library and no icon font. A webfont is a render-blocking network request on a
page whose entire pitch is *"works without a network"*, which is the same
argument that rules out a display font.

| Rule | Value |
|---|---|
| Grid | `24 × 24`, one shared `viewBox` |
| Stroke | `1.5`, `round` caps and joins |
| Fill | none — outline only |
| Colour | `currentColor`, always. A chip recolours by setting `color` once on the parent |
| Weight | one weight for the whole set; never mix filled and outlined glyphs |

**Draw the specific thing, not the category.** Split sourcing is one item
forking to two warehouses, not a generic box. The kitchen display is a screen
with a *cleared ticket* inside it. A glyph that could sit on any other product's
site is not doing its job.

**Slugs live beside the copy, in `i18n.ts`, and are not translated.** Each
`Feature` and `Platform` carries an `icon: GlyphName`, so a translation can
never drift onto the wrong glyph — but a receipt printer is a receipt printer in
all three languages.

**Only directional glyphs mirror in RTL.** `DIRECTIONAL` in `Glyph.tsx` is the
allow-list, and today it holds exactly one member: the refund arrow, because
"back" is the other way in Arabic. Mirroring the whole set is the usual bug — it
hands RTL readers a backwards bar chart and a mirrored calendar.

**The brand mark is not part of this set.** It is traced from
`Front-End/assets/icon.svg` at the icon's own proportions (hub `r = 70/512`,
node `r = 28/512`), filled rather than outlined, and reduced from eight
tentacles to five — eight turn to mud at 22px.

## 5. Layout

- 8px spacing scale: `0.5 / 1 / 1.5 / 2 / 3 / 4 / 6 / 8 rem`.
- Content max width `1200px`; prose max width `68ch`.
- Section padding `clamp(4rem, 10vw, 8rem)` vertical.
- Grids collapse 3 → 2 → 1 at `1024px` / `640px`.
- Generous whitespace *between* sections, tight *within* components.

## 6. Depth & elevation

Borders carry hierarchy; shadows stay near-invisible. On a light ground a heavy
shadow reads as dirt.

```css
--shadow-sm: 0 2px 8px rgb(26 26 46 / 0.08);
--shadow-md: 0 8px 30px rgb(26 26 46 / 0.12);
--shadow-lg: 0 20px 60px rgb(26 26 46 / 0.18);
```

Elevation ladder: `--ground` → `--surface` → `--surface-raised` → `--surface-high`.

## 7. Motion

Per the animation decision framework: **most things should not animate.**

```css
--ease-out:    cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
```

| Element | Duration | Easing |
|---|---|---|
| Button press | 120ms | `--ease-out` |
| Card hover | 180ms | `--ease-out` |
| Nav hairline / scroll reveal | 260ms | `--ease-out` |
| Icon chip fill | 180ms | `--ease-out` |

**Rules**
- `transform` and `opacity` only. Never animate `width`/`height`/`top`/`left`.
- **Never `ease-in`** on UI — it delays the moment the user is watching.
- **Never `scale(0)`** — enter from `scale(0.96)` + `opacity: 0`.
- Everything under 300ms.
- `prefers-reduced-motion: reduce` ships with the animation, never after.
- Hover effects gated behind `@media (hover: hover) and (pointer: fine)`.

## 8. Do's and don'ts

✅ **Do**
- Lead with the offline-first claim — it is the real differentiator.
- Use concrete numbers from the product (5 apps, 3 languages, Windows + Android).
- Keep copy short. Operators skim.
- Ship semantic HTML: real `<section>`, `<nav>`, one `<h1>`.
- Give every feature a glyph, and draw the specific mechanism it describes.

❌ **Don't**
- No stock photos of smiling baristas.
- No fake testimonials, fake logos, fake customer counts, or invented certifications.
- No gradient text on headings.
- No autoplaying video or parallax.
- No cookie banner theatre — the site sets no cookies. (`localStorage` holds
  the chosen accent and nothing else; it never leaves the browser.)
- Don't animate anything a visitor sees on every scroll.
- No icon library, no icon font, no emoji standing in for an icon.
- **Never hardcode an accent hex in a component.** Everything reads the tokens,
  which is the only reason one `setProperty` call can restyle the whole page.
- Screenshots in the hero are REAL captures of the running app. Never a mockup,
  never a render — see `MEDIA_PROMPTS.md` §0.
- Don't mirror the whole icon set in RTL — only the directional ones.
- Don't add a second dark band. There is one, and it is the footer.

## 9. Agent prompt guide

> Build a section for the Octopus POS marketing site. Light operator-grade
> aesthetic on `#FFFFFF` with `#FDF3F3` alternating sections, cards `#FFFFFF`
> with `#F1E6E6` hairline borders, headings in the brand navy `#1A1A2E` at
> weight 300. The accent is a blood red `#A4161A` at 7.75:1 — dark enough to
> serve as shape, fill AND text, with `#801114` as the hover fill. Never
> hardcode it: read the tokens, because the page re-themes from any colour. Icons are hand-drawn 24×24 outline glyphs,
> stroke 1.5, `currentColor`, from `app/components/Glyph.tsx` — never an icon
> library or icon font. System font stack, tight tracking on large headings,
> prose capped at 65ch. Motion: `transform`/`opacity` only,
> `cubic-bezier(0.23, 1, 0.32, 1)`, under 300ms, `prefers-reduced-motion`
> honoured, hover gated behind `@media (hover: hover)`. Reveals are gated on
> `@media (scripting: enabled)` — never reintroduce an inline `<html>` class
> script, it breaks hydration. The footer is the page's only dark band. No
> invented customers, logos, or metrics.

**Quick reference:** ground `#FFFFFF` · surface `#FDF3F3` · border `#F1E6E6` ·
accent `#A4161A` (shape, fill AND text — 7.75:1) · accent-hover `#801114` ·
accent-dim `#F2DEDE` · ink `#1A1A2E` · muted `#4A4A5E` · faint `#686D85` ·
navy band `#1A1A2E → #16213E` on `#F4F5FB` / `#A9AEC9`
