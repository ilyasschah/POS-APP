import Link from "next/link";
import type { ReactNode } from "react";

/**
 * A plain <a> for an in-page anchor, a Next <Link> for anything else.
 *
 * An in-page jump needs nothing from the router — the browser scrolls, and
 * `scroll-behavior: smooth` does the rest. A link to another page gets the
 * router's prefetch and client-side transition.
 */
export default function SiteLink({
  href,
  className,
  current = false,
  children,
}: {
  href: string;
  className?: string;
  current?: boolean;
  children: ReactNode;
}) {
  const ariaCurrent = current ? "page" : undefined;
  return href.startsWith("#") ? (
    <a href={href} className={className} aria-current={ariaCurrent}>
      {children}
    </a>
  ) : (
    <Link href={href} className={className} aria-current={ariaCurrent}>
      {children}
    </Link>
  );
}
