"use client";

import { useState } from "react";
import Image from "next/image";
import Reveal from "./components/Reveal";
import OfflineDiagram from "./components/OfflineDiagram";
import { DICTS, LANGS, dirOf, type Lang } from "./i18n";

export default function Home() {
  // Session-scoped on purpose. Reading a saved language on mount would mean
  // either a setState inside an effect (a cascading render) or a lazy
  // initialiser that reads localStorage — which renders a different language on
  // the client than the server sent, i.e. the hydration mismatch that already
  // crashed this dev server once. Persisting it properly needs locale routes.
  const [lang, setLang] = useState<Lang>("en");
  const t = DICTS[lang];
  const dir = dirOf(lang);
  const rtl = dir === "rtl";

  return (
    <div dir={dir} lang={lang}>
      <header
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          backdropFilter: "blur(12px)",
          background: "color-mix(in srgb, var(--ground) 80%, transparent)",
          borderBottom: "1px solid var(--border)",
        }}
      >
        <nav
          className="shell"
          aria-label="Main"
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            height: "64px",
          }}
        >
          <a href="#top" style={{ display: "flex", alignItems: "center", gap: "0.625rem" }}>
            <Mark />
            <span style={{ fontWeight: 600, letterSpacing: "-0.01em" }}>Octopus POS</span>
          </a>

          <div style={{ display: "flex", alignItems: "center", gap: "1.25rem" }}>
            <a href="#offline" className="nav-link">{t.nav.offline}</a>
            <a href="#features" className="nav-link">{t.nav.features}</a>
            <a href="#platforms" className="nav-link">{t.nav.platforms}</a>
            <a href="#pricing" className="nav-link">{t.nav.pricing}</a>

            <div className="langbar" role="group" aria-label="Language">
              {LANGS.map((l) => (
                <button
                  key={l.code}
                  type="button"
                  onClick={() => setLang(l.code)}
                  className="langbtn"
                  aria-pressed={lang === l.code}
                  lang={l.code}
                >
                  {l.label}
                </button>
              ))}
            </div>

            <a href="#contact" className="btn btn-primary">{t.nav.demo}</a>
          </div>
        </nav>
      </header>

      <main id="top">
        {/* ---------------- Hero ---------------- */}
        <section className="section" style={{ paddingTop: "clamp(3rem,8vw,6rem)" }}>
          <div className="shell">
            <div className="hero-grid">
              <div>
                <Reveal>
                  <p className="eyebrow">{t.hero.eyebrow}</p>
                  <h1>{t.hero.h1}</h1>
                  <p className="lede" style={{ marginTop: "1.5rem", fontSize: "1.125rem" }}>
                    {t.hero.lede}
                  </p>
                  <div style={{ display: "flex", gap: "0.875rem", marginTop: "2.5rem", flexWrap: "wrap" }}>
                    <a href="#contact" className="btn btn-primary">{t.hero.cta}</a>
                    <a href="#offline" className="btn btn-secondary">{t.hero.cta2}</a>
                  </div>
                </Reveal>
              </div>

              <Reveal delay={80}>
                <div className="hero-art">
                  <Image
                    src="/brand-mark.webp"
                    alt=""
                    width={520}
                    height={520}
                    priority
                    style={{ width: "100%", height: "auto", borderRadius: "18px" }}
                  />
                </div>
              </Reveal>
            </div>

            <Reveal delay={120}>
              <dl
                style={{
                  display: "flex",
                  gap: "3rem",
                  marginTop: "4rem",
                  flexWrap: "wrap",
                  borderTop: "1px solid var(--border)",
                  paddingTop: "2rem",
                }}
              >
                {t.stats.map((s) => (
                  <Stat key={s.label} value={s.value} label={s.label} sub={s.sub} />
                ))}
              </dl>
            </Reveal>
          </div>
        </section>

        {/* ---------------- Offline ---------------- */}
        <section id="offline" className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.offline.eyebrow}</p>
              <h2 className="measure">{t.offline.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.offline.lede}</p>
            </Reveal>

            <Reveal delay={80}>
              <div style={{ marginTop: "3.5rem" }}>
                <OfflineDiagram d={t.diagram} />
              </div>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3.5rem" }}>
              {t.offline.steps.map((s, i) => (
                <Reveal key={s.t} delay={i * 60}>
                  <div className="card" style={{ height: "100%" }}>
                    <span style={{ fontFamily: "ui-monospace, Menlo, monospace", fontSize: "0.75rem", color: "var(--accent-ink)" }}>
                      0{i + 1}
                    </span>
                    <h3 style={{ marginTop: "0.75rem" }}>{s.t}</h3>
                    <p style={{ marginTop: "0.625rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>{s.d}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------- Features ---------------- */}
        <section id="features" className="section">
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.features.eyebrow}</p>
              <h2 className="measure">{t.features.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.features.lede}</p>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3rem" }}>
              {t.features.items.map((f, i) => (
                <Reveal key={f.title} delay={(i % 3) * 60}>
                  <div className="card card-interactive" style={{ height: "100%" }}>
                    <h3>{f.title}</h3>
                    <p style={{ marginTop: "0.625rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>{f.body}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------- Platforms ---------------- */}
        <section id="platforms" className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.platforms.eyebrow}</p>
              <h2 className="measure">{t.platforms.h2}</h2>
            </Reveal>

            <div className="grid grid-2" style={{ marginTop: "3rem" }}>
              {t.platforms.items.map((p, i) => (
                <Reveal key={p.name} delay={(i % 2) * 60}>
                  <div className="card card-interactive" style={{ height: "100%", display: "flex", gap: "1rem", alignItems: "flex-start" }}>
                    <div
                      aria-hidden="true"
                      style={{ width: "8px", height: "8px", borderRadius: "50%", background: "var(--accent)", marginTop: "0.6rem", flexShrink: 0 }}
                    />
                    <div>
                      <h3>{p.name}</h3>
                      <p style={{ marginTop: "0.375rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>{p.detail}</p>
                    </div>
                  </div>
                </Reveal>
              ))}
            </div>

            <Reveal delay={120}>
              <div className="card" style={{ marginTop: "1.25rem" }}>
                <h3>{t.platforms.floorTitle}</h3>
                <p className="measure" style={{ marginTop: "0.625rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>
                  {t.platforms.floorBody}
                </p>
              </div>
            </Reveal>
          </div>
        </section>

        {/* ---------------- Pricing ---------------- */}
        <section id="pricing" className="section">
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.pricing.eyebrow}</p>
              <h2 className="measure">{t.pricing.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.pricing.lede}</p>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3rem" }}>
              {t.pricing.tiers.map((tier, i) => (
                <Reveal key={tier.name} delay={i * 60}>
                  <div className="plan">
                    <div className="plan-head">
                      <div className="name">{tier.name}</div>
                      <div className="note">{tier.note}</div>
                    </div>
                    <div className="plan-body">
                      <ul>
                        {tier.points.map((pt, j) => (
                          <li key={pt} className={j === 0 ? "strong" : undefined}>
                            <Check />
                            <span>{pt}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                    <a href="#contact" className="plan-cta">{t.pricing.cta}</a>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------- FAQ ---------------- */}
        <section className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.faq.eyebrow}</p>
              <h2>{t.faq.h2}</h2>
            </Reveal>
            <div style={{ marginTop: "2.5rem", display: "grid", gap: "0.75rem", maxWidth: "820px" }}>
              {t.faq.items.map((item, i) => (
                <Reveal key={item.q} delay={i * 40}>
                  <details className="card">
                    <summary
                      style={{
                        cursor: "pointer",
                        fontWeight: 500,
                        listStyle: "none",
                        display: "flex",
                        justifyContent: "space-between",
                        gap: "1rem",
                        alignItems: "center",
                      }}
                    >
                      {item.q}
                      <span aria-hidden="true" style={{ color: "var(--accent-ink)", flexShrink: 0 }}>+</span>
                    </summary>
                    <p style={{ marginTop: "0.875rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>{item.a}</p>
                  </details>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------- CTA ---------------- */}
        <section id="contact" className="section">
          <div className="shell">
            <Reveal>
              <div className="card" style={{ padding: "clamp(2rem, 6vw, 4rem)", textAlign: "center" }}>
                <h2>{t.contact.h2}</h2>
                <p className="lede" style={{ marginTop: "1rem", marginInline: "auto", maxWidth: "52ch" }}>
                  {t.contact.lede}
                </p>
                <div style={{ display: "flex", gap: "0.875rem", justifyContent: "center", marginTop: "2rem", flexWrap: "wrap" }}>
                  <a href="mailto:hello@example.com" className="btn btn-primary">{t.contact.cta}</a>
                  <a href="mailto:hello@example.com" className="btn btn-secondary">{t.contact.cta2}</a>
                </div>
              </div>
            </Reveal>
          </div>
        </section>
      </main>

      <footer style={{ borderTop: "1px solid var(--border)", paddingBlock: "2.5rem" }}>
        <div
          className="shell"
          style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: "1rem", flexWrap: "wrap" }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "0.625rem" }}>
            <Mark />
            <span style={{ color: "var(--text-faint)", fontSize: "0.875rem" }}>
              © {new Date().getFullYear()} Octopus POS
            </span>
          </div>
          <span style={{ color: "var(--text-faint)", fontSize: "0.875rem", textAlign: rtl ? "left" : "right" }}>
            {t.footer.tagline}
          </span>
        </div>
      </footer>
    </div>
  );
}

/* -------------------------------------------------------------------------- */

function Stat({ value, label, sub }: { value: string; label: string; sub: string }) {
  return (
    <div>
      <dt style={{ fontSize: "2.25rem", fontWeight: 300, letterSpacing: "-0.02em", lineHeight: 1 }}>{value}</dt>
      <dd style={{ margin: "0.5rem 0 0" }}>
        <span style={{ display: "block", fontSize: "0.9375rem" }}>{label}</span>
        <span style={{ display: "block", color: "var(--text-faint)", fontSize: "0.8125rem" }}>{sub}</span>
      </dd>
    </div>
  );
}

function Check() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true" style={{ flexShrink: 0, marginTop: "0.3rem" }}>
      <path d="M3 8.5L6 11.5L13 4.5" stroke="var(--accent)" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function Mark() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
      <rect x="1" y="1" width="20" height="20" rx="6" fill="var(--accent)" opacity="0.15" />
      <rect x="1" y="1" width="20" height="20" rx="6" stroke="var(--accent)" strokeWidth="1.25" fill="none" />
      <circle cx="11" cy="11" r="3.25" fill="var(--accent)" />
    </svg>
  );
}
