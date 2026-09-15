"use client";

import Mark from "./Mark";
import SiteLink from "./SiteLink";
import { LANGS, type Dict, type Lang } from "../i18n";

/**
 * The page's one dark moment — the brand hue taken all the way down, closing a
 * light page against the mark it opened with. Shared by every page, and home to
 * the language picker, so a visitor can switch language wherever they are.
 */
export default function SiteFooter({
  t,
  lang,
  onPick,
  page,
}: {
  t: Dict;
  lang: Lang;
  onPick: (next: Lang) => void;
  page: "home" | "help";
}) {
  const home = page === "home";
  const section = (hash: string) => (home ? hash : `/${hash}`);

  return (
    <footer className="site-footer">
      <div className="shell footer-top">
        <div>
          <SiteLink href={home ? "#top" : "/"} className="footer-brand">
            <Mark size={26} />
            <span>Octopus POS</span>
          </SiteLink>
          <p className="footer-tagline">{t.footer.tagline}</p>
        </div>

        <nav className="footer-nav" aria-label={t.footer.nav}>
          <SiteLink href={section("#features")}>{t.nav.features}</SiteLink>
          <SiteLink href={section("#platforms")}>{t.nav.platforms}</SiteLink>
          <SiteLink href={section("#pricing")}>{t.nav.pricing}</SiteLink>
          <SiteLink href="/help" current={page === "help"}>{t.nav.help}</SiteLink>
          <SiteLink href={section("#contact")}>{t.nav.demo}</SiteLink>
        </nav>
      </div>

      <div className="shell footer-base">
        <span>© {new Date().getFullYear()} Octopus POS</span>
        <label className="langpick">
          <span className="sr-only">{t.footer.language}</span>
          <select
            value={lang}
            onChange={(e) => onPick(e.target.value as Lang)}
            aria-label={t.footer.language}
            /* Mobile autofill tags form controls with its own attribute
               before hydration — see the note in layout.tsx. */
            suppressHydrationWarning
          >
            {LANGS.map((l) => (
              <option key={l.code} value={l.code}>{l.name}</option>
            ))}
          </select>
        </label>
      </div>
    </footer>
  );
}
