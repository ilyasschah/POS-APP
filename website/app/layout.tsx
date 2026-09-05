import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE = "https://octopuspos.example";

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: {
    default: "Octopus POS — the complete, customisable point of sale",
    template: "%s · Octopus POS",
  },
  description:
    "A complete point of sale for restaurants and retail. Floor plans, stock, kitchen tickets, loyalty, promotions and reporting across Windows terminals, Android tablets, a kitchen display and the web — in six themes, any accent colour and three languages. And it keeps selling when the connection drops.",
  keywords: [
    "point of sale",
    "POS system",
    "customisable POS",
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
    title: "Octopus POS — the complete, customisable point of sale",
    description:
      "Fifteen modules on one system. Windows and Android terminals, kitchen display, owner dashboard. Six themes, any colour, three languages.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Octopus POS — the complete, customisable point of sale",
    description:
      "Fifteen modules on one system. Windows and Android terminals, kitchen display, owner dashboard. Six themes, any colour, three languages.",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#ffffff",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    /* Android Chrome's autofill and several mobile extensions stamp their own
       attributes (`__gcrremoteframetoken` here, `__gcruniqueid` on form
       controls) onto the DOM before React hydrates. React cannot tell those
       apart from a real server/client divergence, so it reports a hydration
       mismatch for markup this app never emitted. Suppressing it on <html>
       covers the attributes injected there — it does NOT cascade to children,
       so a genuine mismatch anywhere inside the tree is still reported. */
    <html lang="en" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
