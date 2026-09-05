/**
 * Derives the site's whole accent scale from ONE seed colour, the way the POS
 * derives its Material scheme from one accent setting.
 *
 * This is not decoration — it is the demo. The claim on the page is that the
 * product re-themes to whatever an operator picks, so the page has to actually
 * do it, for any colour, without ever dropping below the WCAG bar. That is the
 * hard half: picking a pretty colour is easy, staying legible in it is not.
 *
 * `DESIGN.md` §2 fixes the contract this has to honour for EVERY seed:
 *   --accent        a SHAPE colour — borders, tints, large type      ≥ 3:1 on white
 *   --accent-strong a FILL that carries white text                   ≥ 4.5:1 on white
 *   --accent-hover  the darker partner of that fill                  ≥ 6:1 on white
 *   --accent-ink    small text and links                             ≥ 5.5:1 on white
 *   --accent-dim    a pale tint, never carries text                  —
 *
 * Every one of those targets is a contrast against WHITE, because the site is
 * light-only (DESIGN.md §2). On a dark ground the maths would invert.
 */

/** Saturation ceiling applied while darkening. See `darkenUntil`. */
const MAX_DARK_SATURATION = 0.78;

export type AccentTokens = {
  accent: string;
  accentStrong: string;
  accentHover: string;
  accentInk: string;
  accentDim: string;
  surface: string;
  surfaceHigh: string;
  border: string;
};

/* -------------------------------------------------------------------------- */
/* Colour maths                                                               */
/* -------------------------------------------------------------------------- */

/** `#RGB` or `#RRGGBB` (with or without the hash) to 0-255 channels. */
export function parseHex(hex: string): [number, number, number] | null {
  const clean = hex.trim().replace(/^#/, "");
  const full =
    clean.length === 3
      ? clean
          .split("")
          .map((c) => c + c)
          .join("")
      : clean;
  if (!/^[0-9a-fA-F]{6}$/.test(full)) return null;
  return [
    parseInt(full.slice(0, 2), 16),
    parseInt(full.slice(2, 4), 16),
    parseInt(full.slice(4, 6), 16),
  ];
}

const toHex = (n: number) =>
  Math.round(Math.min(255, Math.max(0, n)))
    .toString(16)
    .padStart(2, "0");

const rgbToHex = (r: number, g: number, b: number) =>
  `#${toHex(r)}${toHex(g)}${toHex(b)}`;

/** WCAG 2.1 relative luminance. */
function luminance(r: number, g: number, b: number): number {
  const lin = (c: number) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

/** Contrast of a colour against pure white. */
export function contrastOnWhite(hex: string): number {
  const rgb = parseHex(hex);
  if (!rgb) return 1;
  return 1.05 / (luminance(rgb[0], rgb[1], rgb[2]) + 0.05);
}

function rgbToHsl(r: number, g: number, b: number): [number, number, number] {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h: number;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return [h, s, l];
}

function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  if (s === 0) {
    const v = l * 255;
    return [v, v, v];
  }
  const hue = (p: number, q: number, t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return [hue(p, q, h + 1 / 3) * 255, hue(p, q, h) * 255, hue(p, q, h - 1 / 3) * 255];
}

/**
 * Walks a colour's LIGHTNESS down until it clears `target` contrast on white.
 *
 * Lightness rather than a straight RGB scale because hue and saturation are the
 * part the operator actually chose — a blue that darkens toward black is still
 * recognisably their blue, while multiplying the channels drifts the hue and
 * hands them a colour they did not pick.
 *
 * The 1% step is fine-grained enough that the result never looks "stepped", and
 * the loop is bounded: at l=0 the colour is black, which clears every target.
 */
function darkenUntil(hex: string, target: number): string {
  const rgb = parseHex(hex);
  if (!rgb) return hex;
  if (contrastOnWhite(hex) >= target) return hex;

  const [h, s0, l0] = rgbToHsl(rgb[0], rgb[1], rgb[2]);
  // A fully saturated colour that has been darkened reads as garish — a deep
  // 100%-saturation red looks like an error state, not a brand. Capping the
  // saturation on the way down is what the hand-tuned brand scale did by eye,
  // and it lands this within a shade of it: derived #C2183E against the
  // hand-picked #C2103F for the hover fill.
  const s = Math.min(s0, MAX_DARK_SATURATION);
  for (let l = l0; l >= 0; l -= 0.01) {
    const [r, g, b] = hslToRgb(h, s, l);
    const candidate = rgbToHex(r, g, b);
    if (contrastOnWhite(candidate) >= target) return candidate;
  }
  return "#000000";
}

/**
 * The neutrals are not neutral — they are the accent at very low saturation and
 * very high lightness, which is why the shipped palette reads as warm pink
 * rather than grey. Leaving them fixed while the accent moved was the tell that
 * gave the demo away: a blue accent on a pink section looks like a bug, not a
 * theme.
 *
 * These three (S, L) pairs are read off the hand-tuned values — #FDF3F5,
 * #F7EDF0, #F1E6E9 — so feeding the brand hue back through reproduces them, and
 * any other hue gets the same relationship to its own accent.
 */
function neutral(hex: string, sat: number, light: number): string {
  const rgb = parseHex(hex);
  if (!rgb) return hex;
  const [h] = rgbToHsl(rgb[0], rgb[1], rgb[2]);
  const [r, g, b] = hslToRgb(h, sat, light);
  return rgbToHex(r, g, b);
}

/**
 * Drops a colour's lightness by a fixed amount, floored at black.
 *
 * `darkenUntil` is a no-op on a seed that ALREADY clears its target, which is
 * exactly what a dark brand like the blood red does — it passes 3:1, 4.6:1 and
 * 6:1 on its own, so every token would collapse onto the same value and the
 * buttons would have no hover state at all. This guarantees a step regardless
 * of where the seed starts.
 */
function darkenBy(hex: string, delta: number): string {
  const rgb = parseHex(hex);
  if (!rgb) return hex;
  const [h, s, l] = rgbToHsl(rgb[0], rgb[1], rgb[2]);
  const [r, g, b] = hslToRgb(h, s, Math.max(0, l - delta));
  return rgbToHex(r, g, b);
}

/** A pale wash of the seed — the tint behind an icon chip. Never carries text. */
function tint(hex: string): string {
  const rgb = parseHex(hex);
  if (!rgb) return hex;
  const [h, s] = rgbToHsl(rgb[0], rgb[1], rgb[2]);
  // Saturation is held well down. A pale wash of a saturated red at 91%
  // lightness comes out PINK, which is the one thing the brand is not — the
  // tint has to read as a warm neutral carrying the hue, not as a second
  // brand colour.
  const [r, g, b] = hslToRgb(h, Math.min(s, 0.45), 0.91);
  return rgbToHex(r, g, b);
}

/* -------------------------------------------------------------------------- */
/* The public API                                                             */
/* -------------------------------------------------------------------------- */

/**
 * The seven swatches the POS itself offers.
 *
 * Taken verbatim from `Front-End/lib/onboarding/widgets/setup_slide.dart`, in
 * the same order, brand first. That is the point: the picker on this page is
 * not a website gimmick with invented colours, it is the product's own palette.
 * If that list changes in the app, change it here too.
 */
export const POS_ACCENTS = [
  "#A4161A",
  "#3B82F6",
  "#8B5CF6",
  "#EF4444",
  "#F59E0B",
  "#10B981",
  "#EC4899",
] as const;

export const DEFAULT_ACCENT = POS_ACCENTS[0];

/** The one of two colours with the higher contrast on white, i.e. the darker. */
function darker(a: string, b: string): string {
  return contrastOnWhite(a) >= contrastOnWhite(b) ? a : b;
}

export function deriveAccentTokens(seed: string): AccentTokens {
  const safe = parseHex(seed) ? seed : DEFAULT_ACCENT;
  return {
    // Even the "raw" brand colour is floored at 3:1. A neon yellow used as a
    // border would otherwise be invisible on white — the operator still sees
    // their exact choice in the swatch, but the UI uses a shade that can be
    // seen. This is the same call the app makes when it generates a scheme
    // rather than painting with the seed directly.
    accent: darkenUntil(safe, 3),
    // 4.6 rather than 4.5: the loop stops at the FIRST shade that clears the
    // target, so a 4.5 target lands exactly on the bar and any rounding in a
    // browser's compositor could tip it under. The extra tenth is free.
    accentStrong: darkenUntil(safe, 4.6),
    // Whichever is darker: the contrast target, or a guaranteed step down from
    // the fill. On a light seed the target wins; on a dark one the step does,
    // and the button keeps a visible hover either way.
    accentHover: darker(darkenUntil(safe, 6), darkenBy(darkenUntil(safe, 4.6), 0.08)),
    accentInk: darkenUntil(safe, 5.5),
    accentDim: tint(safe),
    surface: neutral(safe, 0.714, 0.9725),
    surfaceHigh: neutral(safe, 0.384, 0.949),
    border: neutral(safe, 0.282, 0.9235),
  };
}

/** CSS custom property name for each derived token. */
export const TOKEN_VARS: Record<keyof AccentTokens, string> = {
  accent: "--accent",
  accentStrong: "--accent-strong",
  accentHover: "--accent-hover",
  accentInk: "--accent-ink",
  accentDim: "--accent-dim",
  surface: "--surface",
  surfaceHigh: "--surface-high",
  border: "--border",
};

/**
 * Writes the derived scale onto :root.
 *
 * The brand accent CLEARS the inline properties instead of setting them, so it
 * falls back to the hand-tuned scale in `globals.css`. Those values were
 * measured and tuned by eye and sit a shade off what this function derives; if
 * the default overwrote them, picking "brand" would land on a slightly
 * different red than the page loaded with, and the reset would look like a bug.
 * Every other seed is derived.
 */
export function applyAccent(seed: string): void {
  const root = document.documentElement;
  const keys = Object.keys(TOKEN_VARS) as (keyof AccentTokens)[];

  if (seed.toLowerCase() === DEFAULT_ACCENT.toLowerCase()) {
    keys.forEach((key) => root.style.removeProperty(TOKEN_VARS[key]));
    return;
  }

  const tokens = deriveAccentTokens(seed);
  keys.forEach((key) => root.style.setProperty(TOKEN_VARS[key], tokens[key]));
}
