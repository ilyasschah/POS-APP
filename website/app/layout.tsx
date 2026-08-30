import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE = "https://octopuspos.example";

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: {
    default: "Octopus POS — the point of sale that keeps selling offline",
    template: "%s · Octopus POS",
  },
  description:
    "An offline-first point of sale for restaurants and retail. Windows touch terminals and Android tablets, a kitchen display, and an owner dashboard — every sale written locally first, so the till never stops when the internet does.",
  keywords: [
    "point of sale",
    "POS system",
    "offline POS",
    "restaurant POS",
    "retail POS",
    "kitchen display system",
    "Android POS tablet",
    "Windows POS",
  ],
  openGraph: {
    type: "website",
    url: SITE,
    siteName: "Octopus POS",
    title: "Octopus POS — the point of sale that keeps selling offline",
    description:
      "Offline-first POS for restaurants and retail. Windows and Android terminals, kitchen display, owner dashboard.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Octopus POS — the point of sale that keeps selling offline",
    description:
      "Offline-first POS for restaurants and retail. Windows and Android terminals, kitchen display, owner dashboard.",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#15202b",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <head>
        {/* Opts the page into the hidden-then-revealed starting state, and only
            when JS is actually running. Inline and render-blocking on purpose:
            it must land before first paint, or elements flash visible and then
            snap to hidden. Everything degrades to plain visible content. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `document.documentElement.classList.add('js')`,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
