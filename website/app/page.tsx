import Reveal from "./components/Reveal";
import OfflineDiagram from "./components/OfflineDiagram";

/* Feature copy is grounded in modules that actually exist under Front-End/lib.
   Nothing here describes capability the product does not have. */
const FEATURES = [
  {
    title: "Floor plan & tables",
    body: "Lay out the room, move covers between tables, split and merge bills. Table state survives a lost connection.",
  },
  {
    title: "Kitchen display",
    body: "Orders reach the pass over the local network. The KDS keeps running on the shop LAN with no internet at all.",
  },
  {
    title: "Stock & split sourcing",
    body: "Allocate stock per line item, not per cart — product A from one warehouse, product B from another, in a single sale.",
  },
  {
    title: "Modifiers & menus",
    body: "Nested modifier groups, forced choices and price deltas, so a cashier rings a complex order without leaving the cart.",
  },
  {
    title: "Reporting & Z-reports",
    body: "Shift totals, Z-reports, tax breakdowns and product mix — exportable, and translated with the rest of the interface.",
  },
  {
    title: "Bookings",
    body: "Reservations tied to the same floor plan the service runs on, so the room the host sees is the room that exists.",
  },
  {
    title: "Loyalty & customers",
    body: "Customer accounts, loyalty cards, per-customer discounts and store credit, all resolvable while offline.",
  },
  {
    title: "Refunds & voids",
    body: "Audited refunds and voids with reason codes and manager approval, returning stock to the warehouse it came from.",
  },
  {
    title: "Hardware",
    body: "Receipt printers, cash drawers, barcode scanners and scales, on both Windows and Android from a single codebase.",
  },
];

const PLATFORMS = [
  {
    name: "Windows terminal",
    detail:
      "Native .exe for 10‑15\" touch monitors. The full counter experience.",
  },
  {
    name: "Android tablet",
    detail:
      "The same app as an .apk for 10‑13\" tablets. Take orders at the table.",
  },
  {
    name: "Kitchen display",
    detail:
      "A companion screen for the pass, served over the local network.",
  },
  {
    name: "Owner dashboard",
    detail:
      "Takings and trends on the web, plus a native iOS app with a home-screen widget.",
  },
];

const FAQ = [
  {
    q: "What actually happens when the internet drops?",
    a: "Nothing visible. Every sale is written to the terminal's own database first and queued for the server. Staff keep ringing orders, printing receipts and sending tickets to the kitchen. When the link returns, the queue drains and conflicts resolve in the background.",
  },
  {
    q: "Do I need a server in the shop?",
    a: "No. Terminals hold their own data and sync to the hosted API. The kitchen display talks to the terminal over the shop's local network, so the pass keeps working even with no internet at the premises.",
  },
  {
    q: "Can I mix Windows counters and Android tablets?",
    a: "Yes. They are the same application compiled for two targets, sharing one product catalogue, one floor plan and one set of reports.",
  },
  {
    q: "What languages does it support?",
    a: "English, French and Arabic today, including full right-to-left layout — not a mirrored afterthought, but the layout the interface was built against.",
  },
  {
    q: "Can I run more than one location?",
    a: "Yes. Each company is isolated at the data layer, with per-location warehouses, stock and reporting under one owner account.",
  },
];

export default function Home() {
  return (
    <>
      <header
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          backdropFilter: "blur(12px)",
          background: "rgb(15 23 32 / 0.8)",
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
          <a
            href="#top"
            style={{ display: "flex", alignItems: "center", gap: "0.625rem" }}
          >
            <Mark />
            <span style={{ fontWeight: 600, letterSpacing: "-0.01em" }}>
              Octopus POS
            </span>
          </a>
          <div
            style={{ display: "flex", alignItems: "center", gap: "1.75rem" }}
          >
            <a href="#offline" className="nav-link">
              Offline
            </a>
            <a href="#features" className="nav-link">
              Features
            </a>
            <a href="#platforms" className="nav-link">
              Platforms
            </a>
            <a href="#pricing" className="nav-link">
              Pricing
            </a>
            <a href="#contact" className="btn btn-primary">
              Book a demo
            </a>
          </div>
        </nav>
      </header>

      <main id="top">
        {/* ---------------------------------------------------------------- */}
        {/* Hero                                                              */}
        {/* ---------------------------------------------------------------- */}
        <section className="section" style={{ paddingTop: "clamp(3rem,8vw,6rem)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">Offline-first point of sale</p>
              <h1 className="measure">
                The till doesn&rsquo;t stop when the internet does.
              </h1>
              <p
                className="lede measure"
                style={{ marginTop: "1.5rem", fontSize: "1.25rem" }}
              >
                Octopus POS writes every sale to the terminal first and syncs
                afterwards. Windows counters, Android tablets, a kitchen display
                and an owner dashboard &mdash; one system, built to keep trading
                through a dead connection.
              </p>
              <div
                style={{
                  display: "flex",
                  gap: "0.875rem",
                  marginTop: "2.5rem",
                  flexWrap: "wrap",
                }}
              >
                <a href="#contact" className="btn btn-primary">
                  Book a demo
                </a>
                <a href="#offline" className="btn btn-secondary">
                  See how it works
                </a>
              </div>
            </Reveal>

            <Reveal delay={80}>
              <dl
                style={{
                  display: "flex",
                  gap: "3rem",
                  marginTop: "4.5rem",
                  flexWrap: "wrap",
                  borderTop: "1px solid var(--border)",
                  paddingTop: "2rem",
                }}
              >
                <Stat value="2" label="Hardware targets" sub="Windows + Android" />
                <Stat value="4" label="Connected apps" sub="Till, KDS, web, iOS" />
                <Stat value="3" label="Languages" sub="EN / FR / AR with RTL" />
                <Stat value="0" label="Sales lost offline" sub="Local-first writes" />
              </dl>
            </Reveal>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* Offline — the differentiator                                      */}
        {/* ---------------------------------------------------------------- */}
        <section
          id="offline"
          className="section"
          style={{ background: "var(--surface)" }}
        >
          <div className="shell">
            <Reveal>
              <p className="eyebrow">How it works</p>
              <h2 className="measure">
                Most POS systems treat the network as a given.
              </h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>
                Ours treats it as optional. The terminal owns its data. The
                server is where that data goes to be shared &mdash; not where it
                has to live for a cashier to take money.
              </p>
            </Reveal>

            <Reveal delay={80}>
              <div style={{ marginTop: "3.5rem" }}>
                <OfflineDiagram />
              </div>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3.5rem" }}>
              {[
                {
                  t: "Write locally",
                  d: "A sale commits to the terminal's own database the moment it is rung. No round trip, no spinner, no waiting on a link that may not be there.",
                },
                {
                  t: "Queue the change",
                  d: "Each write joins a durable outbound queue that survives the app closing, the tablet dying, and the terminal being unplugged mid-service.",
                },
                {
                  t: "Reconcile on return",
                  d: "When the connection comes back the queue drains in order. Stock movements apply as deltas, so nothing double-counts.",
                },
              ].map((s, i) => (
                <Reveal key={s.t} delay={i * 60}>
                  <div className="card" style={{ height: "100%" }}>
                    <span
                      style={{
                        fontFamily: "ui-monospace, Menlo, monospace",
                        fontSize: "0.75rem",
                        color: "var(--accent)",
                      }}
                    >
                      0{i + 1}
                    </span>
                    <h3 style={{ marginTop: "0.75rem" }}>{s.t}</h3>
                    <p
                      style={{
                        marginTop: "0.625rem",
                        color: "var(--text-muted)",
                        fontSize: "0.9375rem",
                      }}
                    >
                      {s.d}
                    </p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* Features                                                          */}
        {/* ---------------------------------------------------------------- */}
        <section id="features" className="section">
          <div className="shell">
            <Reveal>
              <p className="eyebrow">Features</p>
              <h2 className="measure">Everything a service actually needs.</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>
                Built against real restaurant and retail workflows rather than a
                feature checklist.
              </p>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3rem" }}>
              {FEATURES.map((f, i) => (
                <Reveal key={f.title} delay={(i % 3) * 60}>
                  <div
                    className="card card-interactive"
                    style={{ height: "100%" }}
                  >
                    <h3>{f.title}</h3>
                    <p
                      style={{
                        marginTop: "0.625rem",
                        color: "var(--text-muted)",
                        fontSize: "0.9375rem",
                      }}
                    >
                      {f.body}
                    </p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* Platforms                                                         */}
        {/* ---------------------------------------------------------------- */}
        <section
          id="platforms"
          className="section"
          style={{ background: "var(--surface)" }}
        >
          <div className="shell">
            <Reveal>
              <p className="eyebrow">Platforms</p>
              <h2 className="measure">Four screens, one system.</h2>
            </Reveal>

            <div className="grid grid-2" style={{ marginTop: "3rem" }}>
              {PLATFORMS.map((p, i) => (
                <Reveal key={p.name} delay={(i % 2) * 60}>
                  <div
                    className="card card-interactive"
                    style={{
                      height: "100%",
                      display: "flex",
                      gap: "1rem",
                      alignItems: "flex-start",
                    }}
                  >
                    <div
                      aria-hidden="true"
                      style={{
                        width: "8px",
                        height: "8px",
                        borderRadius: "50%",
                        background: "var(--accent)",
                        marginTop: "0.6rem",
                        flexShrink: 0,
                      }}
                    />
                    <div>
                      <h3>{p.name}</h3>
                      <p
                        style={{
                          marginTop: "0.375rem",
                          color: "var(--text-muted)",
                          fontSize: "0.9375rem",
                        }}
                      >
                        {p.detail}
                      </p>
                    </div>
                  </div>
                </Reveal>
              ))}
            </div>

            <Reveal delay={120}>
              <div
                className="card"
                style={{
                  marginTop: "1.25rem",
                  background: "var(--surface-raised)",
                }}
              >
                <h3>Built for the floor, not the desk</h3>
                <p
                  className="measure"
                  style={{
                    marginTop: "0.625rem",
                    color: "var(--text-muted)",
                    fontSize: "0.9375rem",
                  }}
                >
                  Finger-sized targets rather than mouse-sized ones. Six themes
                  including a dimmed and a night mode for low-light rooms. Full
                  right-to-left layout for Arabic. Layouts that compute their own
                  columns, so a 10-inch tablet and a 15-inch counter monitor both
                  get a layout that fits instead of one that overflows.
                </p>
              </div>
            </Reveal>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* Pricing                                                           */}
        {/* NOTE: placeholder figures — replace with real commercial terms.    */}
        {/* ---------------------------------------------------------------- */}
        <section id="pricing" className="section">
          <div className="shell">
            <Reveal>
              <p className="eyebrow">Pricing</p>
              <h2 className="measure">Per terminal, per month.</h2>
              <p className="lede measure" style={{ marginTop: "1.25rem" }}>
                No transaction fees and no cut of your takings.
              </p>
            </Reveal>

            <div className="grid grid-3" style={{ marginTop: "3rem" }}>
              {[
                {
                  name: "Single",
                  price: "—",
                  note: "One terminal",
                  points: [
                    "One Windows or Android terminal",
                    "Kitchen display included",
                    "Offline-first sync",
                    "Email support",
                  ],
                  featured: false,
                },
                {
                  name: "Venue",
                  price: "—",
                  note: "Up to 5 terminals",
                  points: [
                    "Everything in Single",
                    "Up to five terminals",
                    "Owner dashboard, web + iOS",
                    "Floor plan & bookings",
                    "Priority support",
                  ],
                  featured: true,
                },
                {
                  name: "Group",
                  price: "—",
                  note: "Multi-location",
                  points: [
                    "Everything in Venue",
                    "Unlimited terminals",
                    "Multi-location reporting",
                    "Per-warehouse stock control",
                    "Onboarding & migration",
                  ],
                  featured: false,
                },
              ].map((tier, i) => (
                <Reveal key={tier.name} delay={i * 60}>
                  <div
                    className="card"
                    style={{
                      height: "100%",
                      display: "flex",
                      flexDirection: "column",
                      borderColor: tier.featured
                        ? "var(--accent-dim)"
                        : "var(--border)",
                    }}
                  >
                    <h3>{tier.name}</h3>
                    <p
                      style={{
                        fontSize: "2.5rem",
                        fontWeight: 600,
                        letterSpacing: "-0.02em",
                        marginTop: "0.75rem",
                        lineHeight: 1,
                      }}
                    >
                      {tier.price}
                    </p>
                    <p
                      style={{
                        color: "var(--text-faint)",
                        fontSize: "0.875rem",
                        marginTop: "0.375rem",
                      }}
                    >
                      {tier.note}
                    </p>
                    <ul
                      style={{
                        listStyle: "none",
                        padding: 0,
                        margin: "1.5rem 0 0",
                        display: "grid",
                        gap: "0.625rem",
                        flex: 1,
                      }}
                    >
                      {tier.points.map((pt) => (
                        <li
                          key={pt}
                          style={{
                            display: "flex",
                            gap: "0.625rem",
                            color: "var(--text-muted)",
                            fontSize: "0.9375rem",
                          }}
                        >
                          <Check />
                          <span>{pt}</span>
                        </li>
                      ))}
                    </ul>
                    <a
                      href="#contact"
                      className={`btn ${tier.featured ? "btn-primary" : "btn-secondary"}`}
                      style={{ marginTop: "1.75rem" }}
                    >
                      Talk to us
                    </a>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* FAQ                                                               */}
        {/* ---------------------------------------------------------------- */}
        <section className="section" style={{ background: "var(--surface)" }}>
          <div className="shell">
            <Reveal>
              <p className="eyebrow">Questions</p>
              <h2>Before you ask.</h2>
            </Reveal>
            <div
              style={{
                marginTop: "2.5rem",
                display: "grid",
                gap: "0.75rem",
                maxWidth: "820px",
              }}
            >
              {FAQ.map((item, i) => (
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
                      <span
                        aria-hidden="true"
                        style={{ color: "var(--accent)", flexShrink: 0 }}
                      >
                        +
                      </span>
                    </summary>
                    <p
                      style={{
                        marginTop: "0.875rem",
                        color: "var(--text-muted)",
                        fontSize: "0.9375rem",
                      }}
                    >
                      {item.a}
                    </p>
                  </details>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* ---------------------------------------------------------------- */}
        {/* CTA                                                               */}
        {/* ---------------------------------------------------------------- */}
        <section id="contact" className="section">
          <div className="shell">
            <Reveal>
              <div
                className="card"
                style={{
                  padding: "clamp(2rem, 6vw, 4rem)",
                  textAlign: "center",
                }}
              >
                <h2>See it running.</h2>
                <p
                  className="lede"
                  style={{
                    marginTop: "1rem",
                    marginInline: "auto",
                    maxWidth: "52ch",
                  }}
                >
                  A short walkthrough on your own menu and floor plan &mdash;
                  including pulling the network cable mid-sale, which is the part
                  worth watching.
                </p>
                <div
                  style={{
                    display: "flex",
                    gap: "0.875rem",
                    justifyContent: "center",
                    marginTop: "2rem",
                    flexWrap: "wrap",
                  }}
                >
                  <a href="mailto:hello@example.com" className="btn btn-primary">
                    Book a demo
                  </a>
                  <a href="mailto:hello@example.com" className="btn btn-secondary">
                    Ask a question
                  </a>
                </div>
              </div>
            </Reveal>
          </div>
        </section>
      </main>

      <footer
        style={{
          borderTop: "1px solid var(--border)",
          paddingBlock: "2.5rem",
        }}
      >
        <div
          className="shell"
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: "1rem",
            flexWrap: "wrap",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "0.625rem" }}>
            <Mark />
            <span style={{ color: "var(--text-faint)", fontSize: "0.875rem" }}>
              © {new Date().getFullYear()} Octopus POS
            </span>
          </div>
          <span style={{ color: "var(--text-faint)", fontSize: "0.875rem" }}>
            Built for counters that can&rsquo;t afford to stop.
          </span>
        </div>
      </footer>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* Small presentational pieces                                                 */
/* -------------------------------------------------------------------------- */

function Stat({
  value,
  label,
  sub,
}: {
  value: string;
  label: string;
  sub: string;
}) {
  return (
    <div>
      <dt
        style={{
          fontSize: "2.25rem",
          fontWeight: 600,
          letterSpacing: "-0.02em",
          lineHeight: 1,
        }}
      >
        {value}
      </dt>
      <dd style={{ margin: "0.5rem 0 0" }}>
        <span style={{ display: "block", fontSize: "0.9375rem" }}>{label}</span>
        <span
          style={{
            display: "block",
            color: "var(--text-faint)",
            fontSize: "0.8125rem",
          }}
        >
          {sub}
        </span>
      </dd>
    </div>
  );
}

function Check() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      aria-hidden="true"
      style={{ flexShrink: 0, marginTop: "0.3rem" }}
    >
      <path
        d="M3 8.5L6 11.5L13 4.5"
        stroke="var(--accent)"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function Mark() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="20"
        height="20"
        rx="6"
        fill="var(--accent)"
        opacity="0.15"
      />
      <rect
        x="1"
        y="1"
        width="20"
        height="20"
        rx="6"
        stroke="var(--accent)"
        strokeWidth="1.25"
        fill="none"
      />
      <circle cx="11" cy="11" r="3.25" fill="var(--accent)" />
    </svg>
  );
}
