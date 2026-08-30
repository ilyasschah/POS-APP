"use client";

import { useState } from "react";
import type { Dict } from "../i18n";

/**
 * A playable miniature of the till.
 *
 * Deliberately NOT AI-driven. Ringing an item, totalling a basket and printing a
 * receipt are deterministic — a model would make it slower, cost money per
 * visitor, and occasionally get arithmetic wrong. Everything here is plain state.
 *
 * Money is held in integer cents for the same reason a real till does: 0.1 + 0.2
 * in floating point is not 0.3, and a checkout that rounds wrong is worse than no
 * demo at all.
 */
type Line = { id: string; name: string; cents: number; qty: number };
type Stage = "ringing" | "paying" | "receipt";

const money = (cents: number, locale: string) =>
  new Intl.NumberFormat(locale, { style: "currency", currency: "EUR" }).format(cents / 100);

export default function PosDemo({ d, locale }: { d: Dict["demo"]; locale: string }) {
  const [lines, setLines] = useState<Line[]>([]);
  const [stage, setStage] = useState<Stage>("ringing");
  const [online, setOnline] = useState(true);
  const [queued, setQueued] = useState(0);

  const items = d.items;
  const subtotal = lines.reduce((n, l) => n + l.cents * l.qty, 0);
  const tax = Math.round(subtotal * 0.2);
  const total = subtotal + tax;

  function add(id: string, name: string, cents: number) {
    setStage("ringing");
    setLines((prev) => {
      const hit = prev.find((l) => l.id === id);
      return hit
        ? prev.map((l) => (l.id === id ? { ...l, qty: l.qty + 1 } : l))
        : [...prev, { id, name, cents, qty: 1 }];
    });
  }

  function dec(id: string) {
    setLines((prev) =>
      prev.flatMap((l) => (l.id !== id ? [l] : l.qty > 1 ? [{ ...l, qty: l.qty - 1 }] : [])),
    );
  }

  function pay() {
    if (!lines.length) return;
    setStage("paying");
    // A real terminal shows the card sheet for a beat before it clears. The
    // delay is the interaction, not decoration — removing it makes the receipt
    // appear to precede the payment.
    window.setTimeout(() => {
      setStage("receipt");
      if (!online) setQueued((q) => q + 1);
    }, 900);
  }

  function reset() {
    setLines([]);
    setStage("ringing");
  }

  function toggleLink() {
    const next = !online;
    setOnline(next);
    if (next) setQueued(0); // reconnecting drains the queue
  }

  return (
    <div className="demo">
      {/* ---------------- status bar ---------------- */}
      <div className="demo-bar">
        <span className={`chip ${online ? "chip-on" : "chip-off"}`}>
          <span className="dot" aria-hidden="true" />
          {online ? d.online : d.offline}
        </span>
        {queued > 0 && <span className="chip chip-queue">{d.queued.replace("{n}", String(queued))}</span>}
        <button type="button" className="linkbtn" onClick={toggleLink}>
          {online ? d.cut : d.restore}
        </button>
      </div>

      <div className="demo-grid">
        {/* ---------------- products ---------------- */}
        <div className="demo-pad">
          {items.map((p) => (
            <button
              key={p.id}
              type="button"
              className="tile"
              onClick={() => add(p.id, p.name, p.cents)}
            >
              <span className="tile-emoji" aria-hidden="true">{p.emoji}</span>
              <span className="tile-name">{p.name}</span>
              <span className="tile-price">{money(p.cents, locale)}</span>
            </button>
          ))}
        </div>

        {/* ---------------- cart / receipt ---------------- */}
        <div className="demo-cart">
          {stage === "receipt" ? (
            <div className="receipt" role="status">
              <div className="receipt-head">
                <strong>Octopus POS</strong>
                <span>{d.receipt}</span>
              </div>
              <ul>
                {lines.map((l) => (
                  <li key={l.id}>
                    <span>{l.qty}× {l.name}</span>
                    <span>{money(l.cents * l.qty, locale)}</span>
                  </li>
                ))}
              </ul>
              <div className="receipt-tot">
                <span>{d.total}</span>
                <span>{money(total, locale)}</span>
              </div>
              <p className="receipt-note">
                {online ? d.synced : d.savedLocally}
              </p>
              <button type="button" className="btn btn-secondary demo-reset" onClick={reset}>
                {d.newSale}
              </button>
            </div>
          ) : (
            <>
              <div className="cart-lines">
                {lines.length === 0 && <p className="cart-empty">{d.empty}</p>}
                {lines.map((l) => (
                  <div key={l.id} className="cart-line">
                    <button type="button" className="qty" onClick={() => dec(l.id)} aria-label={`− ${l.name}`}>−</button>
                    <span className="cart-qty">{l.qty}</span>
                    <span className="cart-name">{l.name}</span>
                    <span className="cart-cost">{money(l.cents * l.qty, locale)}</span>
                  </div>
                ))}
              </div>

              <div className="cart-foot">
                <div className="cart-row"><span>{d.subtotal}</span><span>{money(subtotal, locale)}</span></div>
                <div className="cart-row"><span>{d.tax}</span><span>{money(tax, locale)}</span></div>
                <div className="cart-row cart-total"><span>{d.total}</span><span>{money(total, locale)}</span></div>
                <button
                  type="button"
                  className="paybtn"
                  onClick={pay}
                  disabled={!lines.length || stage === "paying"}
                >
                  {stage === "paying" ? d.paying : d.pay}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
