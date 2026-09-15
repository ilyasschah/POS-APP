"use client";

import Image from "next/image";
import Reveal from "./components/Reveal";
import PosDemo from "./components/PosDemo";
import Glyph from "./components/Glyph";
import HeroSlides from "./components/HeroSlides";
import ThemePicker from "./components/ThemePicker";
import SiteHeader from "./components/SiteHeader";
import SiteFooter from "./components/SiteFooter";
import { DICTS } from "./i18n";
import { useSiteLang } from "./useSiteLang";

export default function Home() {
  // English on the first render, then the visitor's own — see useSiteLang.
  const { lang, dir, pick } = useSiteLang();
  const t = DICTS[lang];

  return (
    <div dir={dir} lang={lang}>
      <SiteHeader t={t} page="home" />

      <main id="top">
        {/* ---------------- Hero ---------------- */}
        <section className="section" style={{ paddingTop: "clamp(3rem,8vw,6rem)" }}>
          <div className="shell">
            <div className="hero-copy">
              <Reveal>
                <p className="eyebrow">{t.hero.eyebrow}</p>
                <h1>{t.hero.h1}</h1>
                <p className="lede measure" style={{ marginTop: "1.5rem", fontSize: "1.125rem" }}>
                  {t.hero.lede}
                </p>
                <div style={{ display: "flex", gap: "0.875rem", marginTop: "2.5rem", flexWrap: "wrap" }}>
                  <a href="#contact" className="btn btn-primary">{t.hero.cta}</a>
                  <a href="#demo" className="btn btn-secondary">{t.hero.cta2}</a>
                </div>
              </Reveal>
            </div>

            {/* Real captures of the running app — the only images on this page
                allowed to show a UI, because they are not inventing one. */}
            <Reveal delay={80}>
              <div style={{ marginTop: "3rem" }}>
                <HeroSlides captions={t.hero.slides} labels={t.hero.slidesNav} />
              </div>
            </Reveal>

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

        {/* ---------------- Interactive demo ---------------- */}
        <section id="demo" className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.demo.eyebrow}</p>
              <h2 className="measure">{t.demo.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.demo.lede}</p>
            </Reveal>
            <Reveal delay={80}>
              <div style={{ marginTop: "2.5rem" }}>
                <PosDemo d={t.demo} locale={lang} />
              </div>
            </Reveal>
          </div>
        </section>

        {/* ---------------- Roles ---------------- */}
        <section className="section">
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.roles.eyebrow}</p>
              <h2 className="measure">{t.roles.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.roles.lede}</p>
            </Reveal>

            <div className="grid grid-2" style={{ marginTop: "3rem" }}>
              {t.roles.items.map((r, i) => (
                <Reveal key={r.img} delay={(i % 2) * 60}>
                  <article className="role">
                    <Image
                      src={`/${r.img}.webp`}
                      alt=""
                      width={1200}
                      height={670}
                      sizes="(max-width: 640px) 100vw, 580px"
                    />
                    <div className="role-body">
                      <h3>{r.title}</h3>
                      <p>{r.body}</p>
                    </div>
                  </article>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------- Customise ---------------- */}
        <section id="customise" className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">{t.theme.eyebrow}</p>
              <h2 className="measure">{t.theme.h2}</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>{t.theme.lede}</p>
            </Reveal>
            <Reveal delay={80}>
              <div style={{ marginTop: "2.5rem" }}>
                <ThemePicker
                  labels={{
                    legend: t.theme.legend,
                    custom: t.theme.custom,
                    reset: t.theme.reset,
                    applied: t.theme.applied,
                  }}
                />
              </div>
            </Reveal>
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
                    <span className="glyph"><Glyph name={f.icon} size={24} /></span>
                    <h3 style={{ marginTop: "1.25rem" }}>{f.title}</h3>
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
                    <span className="glyph"><Glyph name={p.icon} size={24} /></span>
                    <div>
                      <h3>{p.name}</h3>
                      <p style={{ marginTop: "0.375rem", color: "var(--text-muted)", fontSize: "0.9375rem" }}>{p.detail}</p>
                    </div>
                  </div>
                </Reveal>
              ))}
            </div>

            <Reveal delay={120}>
              <div className="card card-split" style={{ marginTop: "1.25rem" }}>
                <h3>{t.platforms.floorTitle}</h3>
                <p style={{ color: "var(--text-muted)", fontSize: "0.9375rem" }}>
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

            <div className="grid grid-2" style={{ marginTop: "3rem" }}>
              {t.pricing.tiers.map((tier, i) => (
                <Reveal key={tier.name} delay={i * 60}>
                  <div className="plan">
                    <div className="plan-head">
                      <div className="name">{tier.name}</div>
                      <div className="note">{tier.note}</div>
                      <div className="price">{tier.price}</div>
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

      <SiteFooter t={t} lang={lang} onPick={pick} page="home" />
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
