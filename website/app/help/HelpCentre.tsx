"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import Image from "next/image";
import Glyph from "../components/Glyph";
import SiteFooter from "../components/SiteFooter";
import SiteHeader from "../components/SiteHeader";
import SiteLink from "../components/SiteLink";
import { DICTS } from "../i18n";
import { applyAccent, savedAccent } from "../theme";
import { useSiteLang } from "../useSiteLang";
import { HELP, type HelpArticle, type HelpSection, type HelpShot } from "./content";

export default function HelpCentre() {
  const { lang, dir, pick } = useSiteLang();
  const t = DICTS[lang];
  const h = HELP[lang];
  const [query, setQuery] = useState("");

  // There is no picker on this page, so nothing else re-applies the accent a
  // visitor chose on the home page — without this the help centre would be
  // the one page still painted in the brand blue.
  useEffect(() => {
    const saved = savedAccent();
    if (saved) applyAccent(saved);
  }, []);

  const needle = fold(query.trim());
  const sections = useMemo(() => filterSections(h.sections, needle), [h, needle]);
  const found = sections.reduce((n, s) => n + s.articles.length, 0);

  return (
    <div dir={dir} lang={lang}>
      <SiteHeader t={t} page="help" />

      <main id="top">
        <section className="help-hero">
          <div className="shell">
            <p className="eyebrow">{h.eyebrow}</p>
            <h1>{h.h1}</h1>
            <p className="lede measure help-lede">{h.lede}</p>

            <div className="help-search" role="search">
              <SearchIcon />
              <input
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={h.search.placeholder}
                aria-label={h.search.label}
                autoComplete="off"
                spellCheck={false}
                /* Mobile autofill tags form controls with its own attribute
                   before hydration — see the note in layout.tsx. */
                suppressHydrationWarning
              />
            </div>
            <div className="help-search-status">
              <p aria-live="polite">
                {needle && (found > 0 ? h.articles(found) : h.search.none(query.trim()))}
              </p>
              {needle && (
                <button type="button" className="linkbtn" onClick={() => setQuery("")}>
                  {h.search.clear}
                </button>
              )}
            </div>
          </div>
        </section>

        {/* The topic cards are the map. While searching, the results ARE the
            map, so the cards step aside rather than push them below the fold. */}
        {!needle && (
          <nav className="shell help-topics" aria-label={h.topics}>
            <ul className="grid grid-3">
              {h.sections.map((s) => (
                <li key={s.id}>
                  <a href={`#${s.id}`} className="card card-interactive help-topic">
                    <span className="glyph"><Glyph name={s.icon} size={24} /></span>
                    <span className="help-topic-title">{s.title}</span>
                    <span className="help-topic-summary">{inline(s.summary)}</span>
                    <span className="help-topic-count">{h.articles(s.articles.length)}</span>
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        )}

        {sections.length > 0 && (
          <div className="shell help-body">
            <nav className="help-toc" aria-label={h.onThisPage}>
              <p className="help-toc-title">{h.onThisPage}</p>
              <ul>
                {sections.map((s) => (
                  <li key={s.id}>
                    <a href={`#${s.id}`}>{s.title}</a>
                  </li>
                ))}
              </ul>
            </nav>

            <div className="help-sections">
              {sections.map((s) => (
                <section key={s.id} id={s.id} className="help-section" aria-labelledby={`${s.id}-title`}>
                  <div className="help-section-head">
                    <span className="glyph"><Glyph name={s.icon} size={24} /></span>
                    <div>
                      <h2 id={`${s.id}-title`}>{s.title}</h2>
                      <p>{inline(s.summary)}</p>
                    </div>
                  </div>

                  <div className="help-articles">
                    {s.articles.map((a) =>
                      s.faq ? (
                        <Question key={a.id} a={a} note={h.note} open={needle !== ""} />
                      ) : (
                        <Article key={a.id} a={a} note={h.note} />
                      ),
                    )}
                  </div>
                </section>
              ))}
            </div>
          </div>
        )}

        <section className="shell help-stuck-wrap" aria-labelledby="help-stuck-title">
          <div className="card help-stuck">
            <div>
              <h2 id="help-stuck-title">{h.stuck.h2}</h2>
              <p className="lede">{h.stuck.lede}</p>
            </div>
            <div className="help-stuck-actions">
              <a href="mailto:hello@example.com" className="btn btn-primary">{h.stuck.cta}</a>
              <SiteLink href="/#contact" className="btn btn-secondary">{h.stuck.cta2}</SiteLink>
            </div>
          </div>
        </section>
      </main>

      <SiteFooter t={t} lang={lang} onPick={pick} page="help" />
    </div>
  );
}

/* -------------------------------------------------------------------------- */

function Article({ a, note }: { a: HelpArticle; note: string }) {
  return (
    <article id={a.id} className={`card help-article${a.shot ? " has-shot" : ""}`}>
      <div>
        <h3>{a.title}</h3>
        <ArticleBody a={a} note={note} />
      </div>
      {a.shot && <Shot shot={a.shot} />}
    </article>
  );
}

/** Troubleshooting: the question is the summary, the fix opens under it. */
function Question({ a, note, open }: { a: HelpArticle; note: string; open: boolean }) {
  return (
    // Opened for a search, so a match is never hidden behind a click; left to
    // the reader otherwise.
    <details id={a.id} className="card help-article help-faq" open={open || undefined}>
      <summary>
        <h3>{a.title}</h3>
        <span aria-hidden="true">+</span>
      </summary>
      <ArticleBody a={a} note={note} />
      {a.shot && <Shot shot={a.shot} />}
    </details>
  );
}

/** A real capture of the app — only ever rendered when one exists. */
function Shot({ shot }: { shot: HelpShot }) {
  return (
    <figure className="help-shot">
      <Image
        src={shot.src}
        width={shot.width}
        height={shot.height}
        alt={shot.alt}
        sizes="(max-width: 1024px) 100vw, 440px"
      />
      <figcaption>{shot.caption}</figcaption>
    </figure>
  );
}

function ArticleBody({ a, note }: { a: HelpArticle; note: string }) {
  return (
    <>
      <p className="help-article-summary">{a.summary}</p>
      <ol className="help-steps">
        {a.steps.map((step) => (
          <li key={step}>{inline(step)}</li>
        ))}
      </ol>
      {a.note && (
        <p className="help-note">
          <strong>{note}</strong> {inline(a.note)}
        </p>
      )}
    </>
  );
}

function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" aria-hidden="true">
      <circle cx="10.5" cy="10.5" r="6.25" />
      <path d="m15.25 15.25 5 5" />
    </svg>
  );
}

/** `[[Label]]` marks a word the operator sees on screen; it renders as a chip. */
function inline(text: string): ReactNode[] {
  return text
    .split(/\[\[(.+?)\]\]/)
    .map((part, i) => (i % 2 === 1 ? <span key={i} className="ui-label">{part}</span> : part));
}

/** Case- and accent-blind, so "reglages" finds "Réglages". */
function fold(text: string): string {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function filterSections(sections: HelpSection[], needle: string): HelpSection[] {
  if (!needle) return sections;
  return sections
    .map((s) => ({
      ...s,
      articles: s.articles.filter((a) =>
        fold([s.title, a.title, a.summary, ...a.steps, a.note ?? ""].join(" ").replace(/\[\[|\]\]/g, "")).includes(needle),
      ),
    }))
    .filter((s) => s.articles.length > 0);
}
