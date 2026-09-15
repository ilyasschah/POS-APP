"use client";

import { useEffect, useState } from "react";
import Mark from "./Mark";
import SiteLink from "./SiteLink";
import type { Dict } from "../i18n";

/**
 * The sticky header both pages share.
 *
 * On the home page the section links are in-page anchors; from the help centre
 * they lead back to that section of the home page. Every label comes from the
 * page's own dictionary, so the header always speaks the page's language.
 */
export default function SiteHeader({ t, page }: { t: Dict; page: "home" | "help" }) {
  // The header hairline is earned, not permanent: at rest the nav floats on the
  // page ground, and the rule only appears once there is content behind it to
  // separate. Starts false on both server and client, so nothing to reconcile.
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    // A deep link (/#pricing) jumps the page after this effect has run, and an
    // instant jump can land without emitting a scroll event the listener would
    // catch. Without this re-check, arriving on a deep link paints a header
    // with no hairline over content that is already scrolled past.
    const raf = requestAnimationFrame(onScroll);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("scroll", onScroll);
    };
  }, []);

  const home = page === "home";
  const section = (hash: string) => (home ? hash : `/${hash}`);

  return (
    <header className="site-header" data-scrolled={scrolled}>
      <nav className="shell site-nav" aria-label="Main">
        <SiteLink href={home ? "#top" : "/"} className="site-brand">
          <Mark />
          <span className="site-brand-name">Octopus POS</span>
        </SiteLink>

        <div className="site-nav-links">
          <SiteLink href={section("#features")} className="nav-link nav-section">{t.nav.features}</SiteLink>
          <SiteLink href={section("#platforms")} className="nav-link nav-section">{t.nav.platforms}</SiteLink>
          <SiteLink href={section("#customise")} className="nav-link nav-section">{t.theme.eyebrow}</SiteLink>
          <SiteLink href={section("#pricing")} className="nav-link nav-section">{t.nav.pricing}</SiteLink>
          <SiteLink href="/help" className="nav-link" current={page === "help"}>{t.nav.help}</SiteLink>
          <SiteLink href={section("#contact")} className="btn btn-primary nav-cta">{t.nav.demo}</SiteLink>
        </div>
      </nav>
    </header>
  );
}
