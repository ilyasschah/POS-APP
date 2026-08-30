import type { Dict } from "../i18n";

/**
 * The architecture claim, drawn: the terminal owns its database, the queue sits
 * between it and the server, and the link across the top is the only part that
 * is allowed to fail.
 *
 * Static inline SVG — no animation. A diagram explaining a mechanism should be
 * readable at a glance, not performed.
 *
 * Deliberately NOT mirrored for RTL. Only the labels translate. A left-to-right
 * flow is the convention for a data-flow diagram in every locale, and mirroring
 * the geometry buys nothing while risking reversed text and misplaced anchors.
 */
export default function OfflineDiagram({ d }: { d: Dict["diagram"] }) {
  return (
    <div style={{ overflowX: "auto" }} dir="ltr">
      <svg
        viewBox="0 0 900 260"
        role="img"
        aria-label={d.alt}
        style={{ width: "100%", minWidth: "620px", height: "auto" }}
      >
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--text-faint)" />
          </marker>
          <marker id="arrow-accent" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--accent)" />
          </marker>
        </defs>

        {/* ---------------- Terminal ---------------- */}
        <rect x="20" y="40" width="250" height="180" rx="12" fill="var(--surface-raised)" stroke="var(--border)" />
        <text x="40" y="70" fill="var(--text)" fontSize="15" fontWeight="600">{d.terminal}</text>
        <text x="40" y="90" fill="var(--text-faint)" fontSize="12">{d.terminalSub}</text>

        <rect x="40" y="106" width="210" height="42" rx="8" fill="var(--surface-high)" stroke="var(--accent)" />
        <text x="56" y="132" fill="var(--text)" fontSize="13">{d.localDb}</text>
        <circle cx="232" cy="127" r="4" fill="var(--success)" />

        <rect x="40" y="158" width="210" height="42" rx="8" fill="var(--surface-high)" stroke="var(--border)" />
        <text x="56" y="184" fill="var(--text)" fontSize="13">{d.queue}</text>
        <circle cx="232" cy="179" r="4" fill="var(--warning)" />

        {/* ---------------- Sync link ---------------- */}
        <line x1="278" y1="130" x2="610" y2="130" stroke="var(--text-faint)" strokeWidth="1.5" strokeDasharray="6 5" markerEnd="url(#arrow)" markerStart="url(#arrow)" />
        <rect x="368" y="106" width="152" height="26" rx="13" fill="var(--ground)" stroke="var(--border)" />
        <text x="444" y="124" fill="var(--text-muted)" fontSize="11.5" textAnchor="middle">{d.mayBeOffline}</text>
        <text x="444" y="156" fill="var(--text-faint)" fontSize="11.5" textAnchor="middle">{d.drains}</text>

        {/* ---------------- Server ---------------- */}
        <rect x="620" y="70" width="250" height="120" rx="12" fill="var(--surface-raised)" stroke="var(--border)" />
        <text x="640" y="100" fill="var(--text)" fontSize="15" fontWeight="600">{d.server}</text>
        <text x="640" y="120" fill="var(--text-faint)" fontSize="12">{d.serverSub1}</text>
        <text x="640" y="137" fill="var(--text-faint)" fontSize="12">{d.serverSub2}</text>
        <rect x="640" y="150" width="90" height="24" rx="6" fill="var(--surface-high)" />
        <text x="685" y="166" fill="var(--text-muted)" fontSize="11" textAnchor="middle">SQL Server</text>

        {/* ---------------- KDS over LAN ---------------- */}
        <line x1="145" y1="222" x2="145" y2="242" stroke="var(--accent)" strokeWidth="1.5" markerEnd="url(#arrow-accent)" />
        <text x="162" y="247" fill="var(--accent-ink)" fontSize="12">{d.kds}</text>
      </svg>
    </div>
  );
}
