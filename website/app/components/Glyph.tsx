import type { ReactNode } from "react";

/**
 * The site's line-icon set.
 *
 * Hand-drawn on one 24×24 grid with a single stroke weight, no fills and no
 * icon-font dependency — a webfont would be a render-blocking request on a page
 * whose whole pitch is "works without a network", and the same argument that
 * killed the display font kills an icon font.
 *
 * Every glyph inherits `currentColor`, so a chip recolours on hover by setting
 * `color` once on the parent rather than by swapping assets.
 */
export type GlyphName =
  // Features
  | "floor-plan"
  | "kitchen"
  | "stock"
  | "modifiers"
  | "reports"
  | "bookings"
  | "loyalty"
  | "refunds"
  | "hardware"
  // Platforms
  | "desktop"
  | "tablet"
  | "dashboard";

/**
 * Glyphs that encode a DIRECTION rather than an object, and must therefore
 * mirror in Arabic. A calendar or a bar chart means the same thing in both
 * writing directions; an arrow travelling "back" does not — in RTL, back is
 * the other way. Mirroring the whole set would be the usual bug: flipped
 * clock faces and backwards charts.
 */
const DIRECTIONAL: ReadonlySet<GlyphName> = new Set<GlyphName>(["refunds"]);

const PATHS: Record<GlyphName, ReactNode> = {
  /* Overhead view of a room: boundary plus three covers. */
  "floor-plan": (
    <>
      <rect x="2.75" y="3.25" width="18.5" height="17.5" rx="2.5" />
      <circle cx="8" cy="8.75" r="2.25" />
      <rect x="13" y="6.5" width="5.5" height="4.5" rx="1.25" />
      <circle cx="8" cy="15.75" r="2.25" />
    </>
  ),

  /* The pass display: a screen on a stand, ticket cleared. */
  kitchen: (
    <>
      <rect x="2.5" y="3.75" width="19" height="13" rx="2" />
      <path d="M8.4 10.4l2.3 2.3 4.9-4.9" />
      <path d="M12 16.75v3.5M8.75 20.25h6.5" />
    </>
  ),

  /* Split sourcing: one line item, two warehouses. */
  stock: (
    <>
      <rect x="9.5" y="2.5" width="5" height="5" rx="1" />
      <path d="M12 7.5v3.5" />
      <path d="M6.5 14.5v-2a1.5 1.5 0 0 1 1.5-1.5h8a1.5 1.5 0 0 1 1.5 1.5v2" />
      <rect x="4" y="14.5" width="5" height="5" rx="1" />
      <rect x="15" y="14.5" width="5" height="5" rx="1" />
    </>
  ),

  /* Modifier groups: three choices, each set independently. */
  modifiers: (
    <>
      <path d="M4 7h4M12 7h8" />
      <circle cx="10" cy="7" r="1.85" />
      <path d="M4 12h10M18 12h2" />
      <circle cx="16" cy="12" r="1.85" />
      <path d="M4 17h2M10 17h10" />
      <circle cx="8" cy="17" r="1.85" />
    </>
  ),

  /* Z-report: axis and product mix. */
  reports: (
    <>
      <path d="M4 3.5v16.5h16.5" />
      <rect x="7" y="13" width="3" height="7" rx="1" />
      <rect x="12" y="9" width="3" height="11" rx="1" />
      <rect x="17" y="15.5" width="3" height="4.5" rx="1" />
    </>
  ),

  /* Reservation book. */
  bookings: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2.5" />
      <path d="M3 9.75h18" />
      <path d="M8 2.75v4M16 2.75v4" />
      <path d="M7.25 13.5h2M11.25 13.5h2M15.25 13.5h2" />
      <path d="M7.25 17h2M11.25 17h2" />
    </>
  ),

  /* A regular, recognised. */
  loyalty: (
    <>
      <circle cx="9.75" cy="8.75" r="3.75" />
      <path d="M3.25 20.5a6.5 6.5 0 0 1 13 0" />
      <path d="M19 2.5l1.05 2.45L22.5 6l-2.45 1.05L19 9.5l-1.05-2.45L15.5 6l2.45-1.05z" />
    </>
  ),

  /* Money going back the way it came. */
  refunds: (
    <>
      <path d="M19 5h-8a5 5 0 0 1 0 10H6" />
      <path d="M10 11L6 15l4 4" />
    </>
  ),

  /* Receipt printer, paper up. */
  hardware: (
    <>
      <path d="M7 10V5.5a1 1 0 0 1 1-1h8a1 1 0 0 1 1 1V10" />
      <path d="M9.5 7.5h5" />
      <rect x="3" y="10" width="18" height="9" rx="2" />
      <path d="M6.5 14.75h4.5" />
      <circle cx="17.5" cy="14.75" r="1" />
    </>
  ),

  /* Counter monitor: the one screen with a stand. */
  desktop: (
    <>
      <rect x="2.5" y="4" width="19" height="12.5" rx="2" />
      <path d="M12 16.5v4M8.5 20.5h7" />
    </>
  ),

  /* Tablet: portrait, no stand, thumb bar. */
  tablet: (
    <>
      <rect x="6" y="2" width="12" height="20" rx="2.5" />
      <path d="M10 18.75h4" />
    </>
  ),

  /* Owner view: panels, not a page. */
  dashboard: (
    <>
      <rect x="3" y="3" width="8" height="10" rx="1.5" />
      <rect x="13" y="3" width="8" height="6" rx="1.5" />
      <rect x="13" y="11" width="8" height="10" rx="1.5" />
      <rect x="3" y="15" width="8" height="6" rx="1.5" />
    </>
  ),
};

export default function Glyph({ name, size = 22 }: { name: GlyphName; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={DIRECTIONAL.has(name) ? "glyph-directional" : undefined}
      aria-hidden="true"
      focusable="false"
    >
      {PATHS[name]}
    </svg>
  );
}
