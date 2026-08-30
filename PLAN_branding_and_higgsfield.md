# Plan — Octopus branding rollout + Higgsfield media

**Written:** 2026-08-30 · **Status:** PLAN ONLY — nothing below has been applied.
**Apply in:** a later session. Say *"apply the branding plan"* and start at Phase 0.

---

## 0. What is already done (no action needed)

| Item | State |
|---|---|
| `@higgsfield/cli` | ✅ installed on this PC — v1.1.24, `C:\Users\ILYASS\AppData\Roaming\npm\higgsfield` |
| Companion skills | ✅ installed — 8 skills in `.agents/skills/` (gitignored; `skills-lock.json` is committed) |
| Brand colours | ✅ extracted from `Front-End/assets/icon.svg` (below) |

### ⚠️ Two things only YOU can do — these block Phase 3

1. **Create the Higgsfield account.** I can't sign you up: it needs your email and your
   agreement to their terms. Free-trial credits are finite, which is why Phase 3 is
   ordered cheapest-first.
2. **`higgsfield auth login`.** It opens a browser for sign-in. Run it in your own
   terminal. Verify with `higgsfield auth token` — it currently says *"Not authenticated."*

---

## 1. The brand palette (source of truth)

Lifted from the icon's own gradients in `Front-End/assets/icon.svg` — not invented:

```
Background:  #1A1A2E  →  #16213E     (deep navy)
Octopus:     #FF416C  →  #FF4B2B     (pink-red → orange-red)
```

### 🚨 The contrast problem — decide this before any UI work

`#FF416C` on white is roughly **3.3:1**. That is:

- ❌ **Fails** WCAG AA for body text (needs 4.5:1)
- ✅ Passes for large headings and for UI components / borders (needs 3:1)

You asked for a **light** website using these colours, so this bites immediately. The fix
is a two-token split — *not* abandoning the brand colour:

| Token | Value | Use |
|---|---|---|
| `--brand` | `#FF416C` | Fills, buttons, large headings, graphics — where it is a shape, not a word |
| `--brand-ink` | darker, ~`#C9184A` | Body links, small text on light backgrounds |

**When applying:** compute the real ratio for the chosen `--brand-ink` and confirm ≥ 4.5:1.
Do not eyeball it.

---

## 2. Phase 1 — Recolour the Flutter POS app

**Good news: this is a one-value change, not a repaint.** The app is already built for it.

- `Front-End/lib/core/app_theme.dart:13` — `parseAccentColor(String? hex)` returns
  `Colors.blue` when the hex is null. That default is the only thing making the app blue.
- `Front-End/lib/main.dart:173` — the seed resolves as
  `deviceAccentColorProvider ?? SettingKeys.themeAccentColor`, then feeds
  `buildAppTheme(mode, seed)`. Every theme mode is generated from that seed.

### Steps

1. Change the fallback in `parseAccentColor` from `Colors.blue` to `#FF416C`.
2. Check the seeded default for `SettingKeys.themeAccentColor` (company defaults seeder,
   backend). An existing install may still carry blue in the DB and would keep overriding
   the new default. Decide: leave existing installs alone, or migrate.
3. The dark themes already sit on navy (`#15202B`, `#1C2333`), close to the icon's
   `#1A1A2E` — they should harmonise with no change. **Verify, don't assume.**
4. Check all six theme modes (light / dark / dimmed / night / gray / high_contrast).
   `high_contrast` is the one most likely to break against a mid-tone red.

### Constraints from `CLAUDE.md` — do not violate

- Rule 3: **no hardcoded colours.** This change is legal precisely because it moves a
  *seed*, not because it paints widgets.
- Rule 4: everything else keeps sourcing from `Theme.of(context)`.
- ⚠️ There are already **67 opaque hardcoded colours** across 23 files (audit finding M4).
  Those will **not** follow the new accent and may clash visibly once the app turns red.
  **Fixing M4 should probably come first** — otherwise the recolour looks half-done.

### Verify

`cd Front-End && flutter analyze lib && flutter test` — 1,131 tests pass today; keep it there.

---

## 3. Phase 2 — Website: light theme on brand colours

Currently the opposite of what you asked: dark navy ground (`#0f1720`) with a blue accent
(`#2196f3`).

### Steps

1. **Rewrite `website/DESIGN.md` first**, then the CSS from it. That file is the contract;
   if the CSS moves first, the two drift apart.
2. Invert the tokens in `website/app/globals.css`. It is already fully tokenised — `:root`
   holds the whole palette and no component hardcodes a colour — so this is a token swap,
   not a rewrite.
3. Proposed light palette (**verify contrast when applying**):

```
--paper       #FFFFFF        page ground
--surface     #F7F7FA        cards, alternating sections
--border      #E6E6EF        hairlines
--ink         #1A1A2E        headings  ← the icon's own navy
--ink-muted   #4A4E69        body
--brand       #FF416C        fills, buttons, large type
--brand-warm  #FF4B2B        gradient partner, used sparingly
--brand-ink   ~#C9184A       links + small text  (see §1)
```

4. Keep navy `#1A1A2E` as **text**, not background. That is what ties a light site to the
   dark app icon without either looking arbitrary.
5. One dark navy band (hero or footer) using the real `#1A1A2E → #16213E` gradient — a
   direct quote of the icon.

### Must not regress

- The `@media (scripting: enabled)` reveal mechanism. **Do not** reintroduce an inline
  `<html>` class script — it crashed the dev server with a hydration mismatch.
- `prefers-reduced-motion` and `@media (hover: hover)` gating.
- The site currently commits to a single look. Going light-first, decide **explicitly**
  whether a dark variant is supported, and if so do it token-level.

### Verify

```
cd website && npx eslint app --max-warnings=0 && npm run build && npm run dev
```

Load `http://localhost:3000` and confirm **zero hydration errors** in the terminal.

---

## 4. Phase 3 — Higgsfield media for the POS

**Blocked until §0 is done.** Trial credits are finite, so this is ordered cheapest →
most expensive. Stop whenever you have enough.

Feed the brand into every prompt: navy `#1A1A2E`, red-coral `#FF416C → #FF4B2B`,
"operator-grade, dense, precise — a tool that runs a Friday dinner rush."

| # | Asset | Skill | Why in this order |
|---|---|---|---|
| 1 | Brand kit — palette + style refs locked | `higgsfield-brandkit` | Cheapest, and makes every later generation consistent instead of a lottery |
| 2 | Hero still for the website | `higgsfield-generate` | One image; validates the look before spending on video |
| 3 | Terminal / tablet product shots | `higgsfield-product-photoshoot` | Replaces the currently text-only feature grid |
| 4 | **Short "offline-first" explainer video** | `higgsfield-video-explainer` | ⭐ The one worth paying for — the pitch is *"pull the cable mid-sale and it keeps selling"*, which is far better shown than written |

**Command shape** (confirm against `higgsfield --help` when applying, and read each
`SKILL.md` first — they run with full agent permissions):

```
higgsfield model list --video
higgsfield generate cost <model> --prompt "..."      # price it BEFORE generating
higgsfield generate create <model> --prompt "..."
```

Always run `generate cost` first on a trial.

### Where the assets land

- Website hero + features → `website/public/`, referenced from `page.tsx`.
- ⚠️ Video is heavy. Do **not** commit large `.mp4` files here — this repo's `.git` is
  already 293 MB from committed build artifacts (audit H2). Host externally, or settle
  H2 first.

---

## 5. Suggested order

| Step | Work | Depends on |
|---|---|---|
| 1 | You: create account + `higgsfield auth login` | — |
| 2 | Fix audit M4 (67 hardcoded colours) | — |
| 3 | Phase 1 — app accent → `#FF416C` | step 2 |
| 4 | Phase 2 — website light theme | §1 contrast decision |
| 5 | Phase 3 — Higgsfield assets | steps 1 and 4 |

Steps 2–4 need no Higgsfield account and can start immediately.

---

## 6. Open questions for you

1. **Existing installs:** should tills already running a blue accent flip to red, or keep
   what their operator chose?
2. **Website dark mode:** light-only, or light + dark? Light-only is less work and a valid
   choice — just make it deliberate rather than accidental.
3. **Video hosting:** given the `.git` bloat, where should generated video live?
4. **Trial budget:** how many credits before you decide it works?

---

## Related

- `AUDIT_2026-08-30.md` — M4 (hardcoded colours) and H2 (repo bloat) both intersect here.
- `website/DESIGN.md` — the current dark contract, to be rewritten in Phase 2.
- 🔴 Still open, unrelated to this plan: `kPillar3Encryption = false` in
  `Front-End/lib/database/app_database.dart:6489`.
