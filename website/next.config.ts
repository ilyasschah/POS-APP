import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The dev server is reached over Tailscale as well as localhost, and Next 16
  // blocks cross-origin requests to /__nextjs_font/* and other dev-only
  // resources unless the host is named here. Dev-only — it has no effect on a
  // production build.
  allowedDevOrigins: ["100.114.12.38"],
};

export default nextConfig;
