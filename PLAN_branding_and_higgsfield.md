# Plan — Octopus branding rollout + brand media

**Written:** 2026-08-30 · **Last worked:** 2026-09-05
**Status:** Phases 1 and 2 are **DONE and verified**. Phase 3 no longer uses
Higgsfield — see `MEDIA_PROMPTS.md`.

---

## 0. Where this stands

| Phase | State |
|---|---|
| 1 — Recolour the Flutter POS app | ✅ **Done**, verified by test |
| 2 — Website: light theme on brand colours | ✅ **Done**, plus an icon set and a polish pass |
| 3 — Media | 🔄 **Re-routed** to Gemini + ElevenLabs — prompts written, see `MEDIA_PROMPTS.md` |
| Audit M4 (hardcoded colours) | ✅ Closed — over-reported by ~66; the one real case is fixed |

### Higgsfield is no longer needed

You have Gemini Pro and an ElevenLabs account, which covers the same ground:
Gemini for stills and Veo clips, ElevenLabs for voice and sound effects. **The
full brief now lives in `MEDIA_PROMPTS.md`** — copy-paste prompts, a five-shot
film, the narration script, and where each file is allowed to land.

The `@higgsfield/cli` install and the 8 skills in `.agents/skills/` are still on
this PC and cost nothing to leave there.

---

## 1. The brand palette (source of truth)

Lifted from the icon's own gradients in `Front-End/assets/icon.svg`:

```
Background:  #1A1A2E  →  #16213E     (deep navy)
Octopus:     #F0353B  →  #D62828     (blood red, on the navy plate)
UI accent:   #A4161A                 (blood red, on white)
```

The mark and the interface run the SAME red at two lightnesses, because they sit
on opposite grounds: `#A4161A` measures 7.75:1 on white and 2.20:1 on the navy,
so the icon uses a lifted pair that clears 4.29:1 and 3.41:1 there.

### The contrast problem, and how it was resolved

The brand moved **twice**: blue `#2196F3` → coral `#FF416C` → blood red
`#A4161A`. The coral is the interesting one, because at **3.37:1 on white** it
could carry a border but not a sentence, and the whole token system was built to
work around that: a darkened partner generated beside it for anything textual.

The blood red measures **7.75:1** and clears every bar on its own, so
`--accent`, `--accent-strong` and `--accent-ink` now converge on one value. The
machinery stays because the site re-themes from any colour a visitor picks — the
moment one of them chooses something light, the three diverge again.

| Token | Value | Contrast | Use |
|---|---|---|---|
| `--accent` | `#A4161A` | 7.75:1 | Shapes, fills and text alike |
| `--accent-hover` | `#801114` | 10.46:1 | Forced a step darker — a contrast target alone would leave the button with no hover |
| `--accent-dim` | `#F2DEDE` | — | Pale tint, saturation held down so it does not come back pink |
| App | `ColorScheme.fromSeed` | — | Material generates a contrast-safe pair per mode |

All ratios are measured, not estimated, and are **enforced by tests** — see §2.

---

## 2. Phase 1 — Flutter POS app ✅ DONE

The accent is declared in four places and all four carry `#A4161A`:

| File | What |
|---|---|
| `Front-End/lib/core/app_theme.dart` | `kBrandAccent`, and the `parseAccentColor` fallback |
| `Front-End/lib/app_settings/app_settings_model.dart:611` | the settings default |
| `Front-End/lib/onboarding/widgets/setup_slide.dart:26` | the onboarding picker |
| `Back-End/.../CompanyDefaultsSeeder.cs:257` | `Theme_AccentColor` for new companies |

### Two real bugs the recolour exposed

Both were found by measuring rather than by reading, and both are now pinned by
`Front-End/test/brand_accent_theme_test.dart`:

1. **`gray` mode failed WCAG AA.** It sets `primary: seed` via `copyWith`, but
   `copyWith(primary:)` does **not** update `onPrimary` — so a coral-filled
   button kept the grey scheme's partner, a dark teal, at **3.90:1**. Fixed by
   deriving the partner from the accent actually in force.
   *This plan predicted `high_contrast` would be the mode to break. It wasn't —
   it measures 12.33:1, the best of the six.*

2. **An empty accent produced a fully transparent colour.** `parseAccentColor`
   only guarded against `int.parse` throwing, and the dangerous inputs don't
   throw: an empty string — what a cleared settings field sends — left `FF`,
   which parses as `0x000000FF`, transparent. That paints *invisible* buttons,
   so it would never be reported as a colour bug. Now length-validated.

### Measured contrast, all six modes

| Mode | label on button | body on surface | accent on surface |
|---|---|---|---|
| light | 6.47 | 16.38 | 6.17 |
| dark | 7.70 | 14.32 | 10.88 |
| dimmed | 7.70 | 12.13 | 9.22 |
| night | 7.70 | 20.03 | 11.76 |
| gray | **6.22** (was 3.90) | 14.36 | 5.51 |
| high_contrast | 7.70 | 21.00 | 12.33 |

### Verified

`flutter analyze lib test` — clean. `flutter test` — **1,192 passing.**

### Existing installs — ✅ done, narrowly

`SeedAsync` only ever *adds* a missing key, so every company created before the
rollout kept its blue and would have kept it forever.
`CompanyDefaultsSeeder.BackfillBrandAccentAsync` now moves them, wired into
`DatabaseBootstrapper` beside the other startup backfills.

**It matches the old default exactly.** A company still holding `#2196F3` moves
to coral; a company whose operator picked green keeps green. The narrowness is
the point — a backfill that "makes everything consistent" would silently erase a
deliberate choice.

Two things that would have made it a no-op, both now pinned by
`Back-End/Web-POS.Api.Tests/BrandAccentBackfillTests.cs` (7 tests):

- **Delta sync.** `ApplicationProperty` is an `ISyncableEntity` and terminals
  pull with `?modifiedAfter=`. A row rewritten without a fresh `LastModified` is
  a change no till ever asks for — the accent would be correct in the database
  and invisible on every screen. `AppDbContext.SaveChanges` stamps it; the test
  proves it rather than the code repeating it.
- **Idempotency.** It runs on every startup, so the second pass must not
  re-timestamp rows and trigger a pointless resync on every reboot.

---

## 3. Phase 2 — Website ✅ DONE

Light ground, brand coral, navy as ink. `website/DESIGN.md` is the contract; it
was rewritten first, then reconciled again after a polish pass.

**Delivered:** the light token swap · a hand-drawn 13-glyph icon set
(`website/app/components/Glyph.tsx`) covering every feature and platform · the
real octopus mark in the nav and footer · the dark navy footer band quoting the
icon's own gradient · a scroll-earned header hairline · `.card-split` for
full-width cards that would otherwise strand half their width.

**Decided:** the site is **light-only**, deliberately — reasoning recorded in
`DESIGN.md` §2. It is not an oversight to be fixed later.

### Held to, and verified

- The `@media (scripting: enabled)` reveal mechanism is intact. **No inline
  `<html>` class script** — that is what crashed the dev server with a hydration
  mismatch once already.
- `prefers-reduced-motion` and `@media (hover: hover)` gating throughout.
- Only *directional* glyphs mirror in RTL. Verified in Arabic: the refund arrow
  gets `matrix(-1,0,0,1,0,0)`, every other glyph gets `none`.
- `scrollWidth == innerWidth` at 320 / 390 / 520 / 560 / 1440 — no overflow.
- **Zero console errors or warnings** at every width, driven over CDP.
- `npx eslint app --max-warnings=0` and `npm run build` both clean.

### One caveat for whoever measures this next

**Chrome headless on Windows clamps its window width.** `--window-size=390`
actually lays out at roughly 600px, which makes narrow-viewport findings
unreliable — it produced one convincing false positive (a "clipped" language
picker that is fine at a true 390px). Use CDP
`Emulation.setDeviceMetricsOverride`, or an iframe of fixed width, not
`--window-size`.

### A hydration warning that is not ours

Mobile Chrome's autofill stamps `__gcrremoteframetoken` on `<html>` and
`__gcruniqueid` on form controls before React hydrates, which React reports as a
mismatch. `suppressHydrationWarning` on those two elements silences it. It does
**not** cascade to children, so a genuine mismatch anywhere inside the tree is
still reported.

---

## 4. Phase 3 — Media 🔄 RE-ROUTED

**Now Gemini + ElevenLabs. Full brief: `MEDIA_PROMPTS.md`.**

The brand still drives every prompt: navy `#1A1A2E`, blood red `#A4161A`,
"operator-grade, dense, precise — a tool that runs a Friday dinner rush", and a
Moroccan setting, since the product defaults to dirhams, Africa/Casablanca and
French.

| # | Asset | Tool | Note |
|---|---|---|---|
| 1 | Hero still, 1:1 | Gemini image | Do this one alone and look at it on the real page before spending anything else |
| 2 | Four platform stills, 4:3 | Gemini image | The Platforms cards are glyph-and-text today |
| 3 | Real app screenshots | **The app itself** | Nothing on the site shows the product yet |
| 4 | "Offline-first" film, ~40s | Veo ×5 shots + ElevenLabs VO/SFX | ⭐ *"pull the cable mid-sale and it keeps selling"* |

### 🚨 The rule that governs all of it

**Never let a generator draw the UI.** Veo and Gemini will invent a convincing
point-of-sale interface that is not this product. `DESIGN.md` §8 already bans
invented customers, logos and metrics; an invented *product* is the same promise
broken. Every prompt in `MEDIA_PROMPTS.md` therefore specifies a screen that is
off or not legible to camera — AI supplies the room, you supply the screen.

That makes item 3 a blocker for anything showing a screen: `website/public/`
currently holds `brand-mark.webp` and nothing else.

### Where the assets land

- Stills and the poster frame → `website/public/`, referenced from `page.tsx`.
- ⚠️ **The `.mp4` does not go in this repo.** `.git` is 293 MB and only stopped
  growing this session (§6). The site is IIS-hosted, so put the file beside the
  built site on the server and reference it by URL.
- `DESIGN.md` §8 bans autoplaying video — ship a poster frame and a play control.
- Verify commercial-use terms on both: Veo output carries SynthID and Google's
  terms vary by tier; ElevenLabs' free tier generally requires attribution.

---

## 5. Open questions for you

1. ~~**Existing installs.**~~ Decided: backfill only rows still on the old
   default. Implemented — see §2.
2. ~~**Website dark mode.**~~ Decided: light-only. Recorded in `DESIGN.md` §2.
3. ~~**Video hosting.**~~ Partly settled: the artifacts are untracked (§6), so
   `.git` stops growing — but it is still 293 MB, because the blobs remain in
   past commits. Large video should still be hosted externally.
4. ~~**Trial budget.**~~ Moot — no Higgsfield trial to budget. Gemini and
   ElevenLabs quotas are yours to pace; `MEDIA_PROMPTS.md` §7 orders the work
   cheapest-first so one image tells you whether the look is right.

---

## 6. Audit H2 — build artifacts untracked ✅

**1,569 files removed from the index**, tracked count 3,457 → 1,888. Nothing was
deleted from disk (`git rm --cached`), and no history was rewritten — so every
commit hash is unchanged and nobody has to re-clone.

### Why `.gitignore` had not been enough

It already listed `/build/`, `**/bin/` and `**/obj/`, and the intent was
understood. Two gaps let 736 DLLs through anyway:

1. **`/build/` was anchored to the repo root**, so output that landed at
   `Back-End/Web-POS.Api/build/` and `Front-End/android/build/` sailed past it.
   Now `**/build/`.
2. **Two directories are named after a mangled command line.** A mis-parsed
   `dotnet build -o ... --nologo` created real folders called `build/logo` and
   `POS-APPbuildtest --nologoDebug`, each holding a full copy of the build
   output. Nothing matched them; now `**/*--nologo*/` and `**/POS-APPbuild*/`.

`git ls-files -i -c --exclude-standard` now returns **0**, so the ignore rules
and the index finally agree.

**Checked before removing:** no `.cs`, `.dart`, `.ts`, `.sql`, `.csproj` or
`.sln` file was in the set, and the committed `appsettings*.json` copies carry
empty placeholders, not credentials — real secrets live in the git-ignored
`appsettings.Local.json` or in environment variables.

⚠️ **`.git` is still 293 MB.** Untracking stops the growth; it cannot shrink
what past commits already hold. That needs a history rewrite, which was
declined — reasonably, since it changes every commit hash.

---

## Related

- `AUDIT_2026-08-30.md` — M4 and H2 both closed here (H2 partially: untracked,
  history intact).
- `MEDIA_PROMPTS.md` — the Gemini + ElevenLabs brief that replaces Higgsfield.
- `website/DESIGN.md` — the light contract, including the icon rules.
- `Front-End/test/brand_accent_theme_test.dart` — the contrast bar, enforced.
- 🔴 Still open, unrelated to this plan: `kPillar3Encryption = false` in
  `Front-End/lib/database/app_database.dart:6489`.
