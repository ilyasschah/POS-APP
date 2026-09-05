"use client";

import { useEffect, useState } from "react";
import { POS_ACCENTS, DEFAULT_ACCENT, applyAccent, parseHex } from "../theme";

const STORAGE_KEY = "octopus-accent";

/**
 * Repaints the whole site from one colour — the page's central claim, made
 * checkable rather than asserted.
 *
 * The swatches are the POS's own seven accents, in the app's own order (see
 * `POS_ACCENTS`). That is the difference between a demo and a gimmick: a
 * visitor who later opens the real Settings screen finds the same row of
 * colours they just played with here.
 *
 * Everything downstream is CSS custom properties, so one `setProperty` call
 * restyles buttons, links, chips, the pricing cards, the focus ring and the
 * icon tints at once. Nothing in this component knows what a button looks like.
 */
export default function ThemePicker({
  labels,
}: {
  labels: { legend: string; custom: string; reset: string; applied: string };
}) {
  // Always the brand on first render. The saved choice is read in an effect
  // rather than a lazy initialiser because localStorage does not exist on the
  // server — reading it during render is the classic hydration mismatch, and
  // this file is one `useState(() => localStorage...)` away from the crash that
  // already took out this dev server once.
  const [accent, setAccent] = useState<string>(DEFAULT_ACCENT);

  useEffect(() => {
    let saved: string | null = null;
    try {
      saved = localStorage.getItem(STORAGE_KEY);
    } catch {
      // Private mode, or site data blocked. The brand default is a fine answer.
    }
    if (saved && parseHex(saved)) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setAccent(saved);
      applyAccent(saved);
    }
  }, []);

  function pick(next: string) {
    setAccent(next);
    applyAccent(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Not being able to remember the choice is not a reason to refuse it.
    }
  }

  const isCustom = !POS_ACCENTS.some((c) => c.toLowerCase() === accent.toLowerCase());

  return (
    <div className="picker">
      <div role="radiogroup" aria-label={labels.legend} className="picker-swatches">
        {POS_ACCENTS.map((colour) => {
          const active = colour.toLowerCase() === accent.toLowerCase();
          return (
            <button
              key={colour}
              type="button"
              role="radio"
              aria-checked={active}
              // The hex is the only honest label here — a name like "violet"
              // would be invented, and a screen reader reading "button" seven
              // times in a row is useless.
              aria-label={colour}
              title={colour}
              className="swatch"
              style={{ ["--swatch" as string]: colour }}
              onClick={() => pick(colour)}
            />
          );
        })}

        <label className={`swatch swatch-custom${isCustom ? " is-active" : ""}`} title={labels.custom}>
          <span className="sr-only">{labels.custom}</span>
          <input
            type="color"
            value={accent}
            onChange={(e) => pick(e.target.value)}
            aria-label={labels.custom}
          />
        </label>
      </div>

      <p className="picker-note">
        <span className="picker-chip" aria-hidden="true" />
        {labels.applied}
        {accent.toLowerCase() !== DEFAULT_ACCENT.toLowerCase() && (
          <button type="button" className="linkbtn" onClick={() => pick(DEFAULT_ACCENT)}>
            {labels.reset}
          </button>
        )}
      </p>
    </div>
  );
}
