import { useEffect, useState } from "react";
import { LANGS, detectLang, dirOf, type Lang } from "./i18n";

const STORAGE_KEY = "octopus-lang";

/**
 * The visitor's language, shared by every page on the site.
 *
 * Starts at English so the SSR'd HTML is deterministic — crawlers index the
 * English copy, and server and client agree at hydration. It then corrects
 * itself in an effect: to a language the visitor picked earlier in this tab,
 * otherwise to the browser's preference.
 *
 * The choice is kept in sessionStorage so it survives the click from the home
 * page to the help centre and back. A tab is the right lifetime for "I read
 * this site in French" — it never leaves the browser, and the next visit asks
 * the browser again.
 */
export function useSiteLang() {
  const [lang, setLang] = useState<Lang>("en");

  useEffect(() => {
    let saved: string | null = null;
    try {
      saved = sessionStorage.getItem(STORAGE_KEY);
    } catch {
      // Storage blocked. The browser's preference is a fine answer.
    }
    const next = LANGS.some((l) => l.code === saved)
      ? (saved as Lang)
      : detectLang(navigator.languages ?? [navigator.language]);
    // Reading storage and the browser's language IS synchronising with an
    // external system, which is what an effect is for. It cannot move into a
    // lazy initialiser: that runs during render and would produce different
    // markup on the client than the server sent — the hydration mismatch that
    // crashed this dev server once already.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (next !== "en") setLang(next);
  }, []);

  function pick(next: Lang) {
    setLang(next);
    try {
      sessionStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Not being able to remember the choice is not a reason to refuse it.
    }
  }

  return { lang, dir: dirOf(lang), pick };
}
