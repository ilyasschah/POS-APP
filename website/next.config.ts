import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emit a folder of plain HTML/CSS/JS (`out/`) instead of a server bundle, so
  // IIS can serve this site as static files on the same box as the API. The
  // alternative is running `next start` — a long-lived Node process — next to
  // SQL Server and IIS on an 8 GB VPS, for a site that has no server-side
  // behaviour to speak of: one page, no route handlers, no server actions, and
  // language detection that happens in the browser (see app/i18n.ts).
  output: "export",

  // Static export has no Next.js image optimiser behind it — that endpoint is
  // part of the server this build deliberately does not produce. Without this,
  // `next build` fails outright on the <Image> in app/page.tsx.
  images: { unoptimized: true },

  // The dev server is reached over Tailscale as well as localhost, and Next 16
  // blocks cross-origin requests to /__nextjs_font/* and other dev-only
  // resources unless the host is named here. Dev-only — it has no effect on a
  // production build.
  allowedDevOrigins: ["100.114.12.38"],
};

export default nextConfig;
