# DESIGN.md — Octopus POS marketing site

A plain-text design system for AI agents working on this site. Follows the
[Stitch DESIGN.md convention](https://github.com/voltagent/awesome-design-md).
Motion rules follow [Emil Kowalski's design-engineering skill](https://github.com/emilkowalski/skill).

Palette and surfaces are **derived from the product itself** — the dimmed theme in
`Front-End/lib/core/app_theme.dart` — so the site and the POS look like one product.

---

## 1. Visual theme & atmosphere

Serious software for people running a business, not a consumer app. Dark,
dense, precise. The tone is **operator-grade**: this is a tool that runs the till
during a Friday dinner rush, and the site should feel as dependable as that.

- Dark ground by default. No light-mode toggle — the product's own dimmed theme is the identity.
- Restraint over decoration. Every element earns its place.
- Density over airiness: real numbers, real screens, short sentences.
- Never "playful startup". No gradients-as-personality, no floating 3D blobs.

## 2. Color palette & roles

Taken from the app's dimmed theme so the two read as one product.

| Token | Hex | Role |
|---|---|---|
| `--ground` | `#0F1720` | Page background, deepest layer |
| `--surface` | `#15202B` | Section backgrounds (app `scaffoldBackgroundColor`) |
| `--surface-raised` | `#1C2333` | Cards, panels (app `cardColor`) |
| `--surface-high` | `#263040` | Hover states, nested panels |
| `--border` | `#283045` | Hairlines, card edges |
| `--accent` | `#2196F3` | Primary action, links, focus rings (app default seed) |
| `--accent-hover` | `#42A5F5` | Accent hover |
| `--accent-dim` | `#1565C0` | Pressed, accent borders |
| `--text` | `#F2F5F8` | Headings, primary copy |
| `--text-muted` | `#9BA8B8` | Body, secondary copy |
| `--text-faint` | `#64748B` | Labels, captions, metadata |
| `--success` | `#34D399` | Online / synced states |
| `--warning` | `#FBBF24` | Offline / queued states |

**Rule:** accent is for *action and state*, never for decoration. If a blue thing
isn't clickable or reporting status, it shouldn't be blue.

## 3. Typography

System font stack — no webfont. A font file is a render-blocking network
request on a page whose whole pitch is "works without a network".

| Level | Size / weight | Tracking |
|---|---|---|
| Display (h1) | `clamp(2.5rem, 6vw, 4.5rem)` / 600 | `-0.03em` |
| Section (h2) | `clamp(1.75rem, 3.5vw, 2.75rem)` / 600 | `-0.02em` |
| Card title (h3) | `1.125rem` / 600 | `-0.01em` |
| Body | `1rem` / 400, `line-height: 1.65` | normal |
| Small / label | `0.875rem` / 500 | normal |
| Eyebrow | `0.75rem` / 600, uppercase | `0.12em` |
| Mono | `ui-monospace, "SF Mono", Menlo, monospace` | — |

Tighten tracking as size grows; large type set at normal tracking looks loose.
Cap measure at `68ch`.

## 4. Component styling

**Buttons** — `border-radius: 10px`, `padding: 0.75rem 1.5rem`, weight 500.
- Primary: `--accent` fill, `#fff` text. Hover `--accent-hover`. Active `scale(0.97)`.
- Secondary: transparent, `1px solid --border`. Hover `--surface-high`.
- Every button has an `:active` state. No exceptions.

**Cards** — `--surface-raised`, `1px solid --border`, `border-radius: 14px`,
`padding: 1.75rem`. Hover: border → `--accent-dim`, `translateY(-2px)`. Hover
effects gated behind `@media (hover: hover)`.

**Nav** — sticky, `backdrop-filter: blur(12px)`, background at 80% alpha,
bottom hairline appearing only after scroll.

**Focus** — `2px solid --accent`, `outline-offset: 2px`. Never removed.

## 5. Layout

- 8px spacing scale: `0.5 / 1 / 1.5 / 2 / 3 / 4 / 6 / 8 rem`.
- Content max width `1200px`; prose max width `68ch`.
- Section padding `clamp(4rem, 10vw, 8rem)` vertical.
- Grids collapse 3 → 2 → 1 at `1024px` / `640px`.
- Generous whitespace *between* sections, tight *within* components.

## 6. Depth & elevation

Borders carry hierarchy; shadows are near-invisible. On a dark ground a big soft
shadow reads as mud.

```css
--shadow-sm: 0 1px 2px rgb(0 0 0 / 0.3);
--shadow-md: 0 4px 12px rgb(0 0 0 / 0.35);
--shadow-lg: 0 12px 32px rgb(0 0 0 / 0.45);
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
| Nav / scroll reveal | 260ms | `--ease-out` |

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

❌ **Don't**
- No stock photos of smiling baristas.
- No fake testimonials, fake logos, fake customer counts, or invented certifications.
- No gradient text on headings.
- No autoplaying video or parallax.
- No cookie banner theatre — the site sets no cookies.
- Don't animate anything a visitor sees on every scroll.

## 9. Agent prompt guide

> Build a section for the Octopus POS marketing site. Dark operator-grade
> aesthetic on `#15202B`, cards `#1C2333` with `#283045` hairline borders, accent
> `#2196F3` reserved for action and state only. System font stack, tight tracking
> on large headings, prose capped at 68ch. Motion: `transform`/`opacity` only,
> `cubic-bezier(0.23, 1, 0.32, 1)`, under 300ms, `prefers-reduced-motion`
> honoured, hover gated behind `@media (hover: hover)`. No invented customers,
> logos, or metrics.

**Quick reference:** ground `#0F1720` · surface `#15202B` · raised `#1C2333` ·
border `#283045` · accent `#2196F3` · text `#F2F5F8` · muted `#9BA8B8`
