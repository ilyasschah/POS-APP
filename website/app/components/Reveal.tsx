"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Reveals children once on scroll-in.
 *
 * A scroll reveal is a "rare / first-time" animation — a visitor sees any given
 * section enter once per page load — so it clears the frequency gate. Purpose:
 * preventing a jarring change, not decoration.
 *
 * Fires once and disconnects: re-animating on every scroll past would push this
 * into the "seen tens of times" tier, where the correct amount of motion is none.
 */
export default function Reveal({
  children,
  delay = 0,
  className = "",
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;

    // Reduced motion is handled entirely in CSS — the `prefers-reduced-motion`
    // block in globals.css pins .reveal to its visible state and drops the
    // transition. Doing it here too would mean setState in an effect body (a
    // cascading render) for no behavioural gain.
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -60px 0px" },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={ref}
      className={`reveal ${className}`}
      data-visible={visible}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}
