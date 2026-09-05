"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Image from "next/image";

/**
 * The hero carousel — four real screenshots of the running application.
 *
 * Real, not rendered: these are captures of the actual Flutter build, which is
 * the only reason the page is allowed to show a UI at all (`MEDIA_PROMPTS.md`
 * §0). Every one of them is in the brand accent and in French, because that is
 * what the product ships as by default.
 *
 * Slide ids are stable and the captions are looked up by id, so a translation
 * can never end up describing the wrong screenshot.
 */
export type SlideId = "sale" | "dashboard" | "history" | "display";

const SLIDES: { id: SlideId; src: string; full: string; w: number; h: number }[] = [
  { id: "sale", src: "/mid_sale.webp", full: "/mid_sale-full.webp", w: 1600, h: 938 },
  { id: "dashboard", src: "/dashboard.webp", full: "/dashboard-full.webp", w: 1600, h: 928 },
  { id: "history", src: "/sales_history.webp", full: "/sales_history-full.webp", w: 1600, h: 937 },
  { id: "display", src: "/customer_display_web.webp", full: "/customer_display_web-full.webp", w: 1600, h: 839 },
];

const ADVANCE_MS = 6000;

export default function HeroSlides({
  captions,
  labels,
}: {
  captions: Record<SlideId, string>;
  labels: {
    previous: string;
    next: string;
    region: string;
    enlarge: string;
    close: string;
    zoomIn: string;
    zoomOut: string;
  };
}) {
  const [index, setIndex] = useState(0);
  // Once someone drives the carousel themselves, it stops driving itself. An
  // element that keeps moving under a user who has taken hold of it is the
  // single most complained-about carousel behaviour.
  const [held, setHeld] = useState(false);
  const [paused, setPaused] = useState(false);
  const [reduced, setReduced] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  // The lightbox. `open` drives showModal/close rather than the dialog being
  // rendered conditionally, so the element keeps its identity and the browser
  // handles focus trapping, Escape and the top layer for us.
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState(false);
  // Fit-to-screen by default; 1:1 with scrolling when a visitor wants to read
  // the actual pixels. That second state is the whole reason this exists — a
  // 2600px screenshot fitted to a phone is exactly as unreadable as the 358px
  // one it came from.
  const [zoomed, setZoomed] = useState(false);
  const stageRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const sync = () => setReduced(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  const go = useCallback((next: number) => {
    setIndex((next + SLIDES.length) % SLIDES.length);
  }, []);

  useEffect(() => {
    // `prefers-reduced-motion` disables the automatic advance outright rather
    // than merely removing the fade. The problem for that user is not the
    // transition, it is content moving without being asked.
    if (reduced || held || paused) return;
    const t = setInterval(() => setIndex((n) => (n + 1) % SLIDES.length), ADVANCE_MS);
    return () => clearInterval(t);
  }, [reduced, held, paused]);

  function take(next: number) {
    setHeld(true);
    go(next);
  }

  useEffect(() => {
    const el = dialogRef.current;
    if (!el) return;
    if (open && !el.open) {
      // Open at ACTUAL SIZE on a narrow screen. Fitting a 2600px screenshot to
      // a 390px phone reproduces the thumbnail the visitor just tapped, so a
      // fit-first default would answer "let me see that properly" with the
      // exact image they could already see.
      setZoomed(window.innerWidth < 900);
      el.showModal();
    }
    if (!open && el.open) el.close();
  }, [open]);

  // Land in the MIDDLE of an enlarged screenshot, not its top-left corner.
  // Scrolled to the corner, a zoomed image opens on a window chrome and a
  // hamburger — the least informative part of any of these captures.
  useEffect(() => {
    const stage = stageRef.current;
    if (!open || !zoomed || !stage) return;
    const centre = () => {
      stage.scrollLeft = (stage.scrollWidth - stage.clientWidth) / 2;
      stage.scrollTop = (stage.scrollHeight - stage.clientHeight) / 2;
    };
    centre();
    // Again once the full-resolution file has decoded, because until then the
    // stage has nothing to scroll and the first call is a no-op.
    const img = stage.querySelector("img");
    img?.addEventListener("load", centre, { once: true });
    return () => img?.removeEventListener("load", centre);
  }, [open, zoomed, index]);

  // Escape and the backdrop both fire the dialog's own `close` event, so React
  // state is synced from the element rather than every dismissal path having to
  // remember to call setOpen(false).
  useEffect(() => {
    const el = dialogRef.current;
    if (!el) return;
    const onClose = () => {
      setOpen(false);
      setZoomed(false);
    };
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, []);

  // The page must not scroll behind an open lightbox.
  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  /**
   * Swipe, because on a phone that is how people expect to move a carousel and
   * the arrows are a fallback rather than the primary gesture.
   *
   * Pointer events rather than touch events: one code path covers finger, pen
   * and a mouse drag. The 40px threshold is high enough that a vertical page
   * scroll which wanders sideways does not count as a swipe.
   */
  const swipeFrom = useRef<{ x: number; y: number } | null>(null);

  function onPointerDown(e: React.PointerEvent) {
    swipeFrom.current = { x: e.clientX, y: e.clientY };
  }

  function onPointerUp(e: React.PointerEvent) {
    const from = swipeFrom.current;
    swipeFrom.current = null;
    if (!from) return;
    const dx = e.clientX - from.x;
    const dy = e.clientY - from.y;
    // Ignore anything that was mostly vertical — that was a scroll, not a swipe.
    if (Math.abs(dx) < 40 || Math.abs(dx) < Math.abs(dy)) return;
    // Mirrored in Arabic, so the gesture agrees with the arrows beside it.
    const rtl = rootRef.current?.closest("[dir=rtl]") != null;
    const forward = rtl ? dx > 0 : dx < 0;
    take(index + (forward ? 1 : -1));
  }

  return (
    <div
      ref={rootRef}
      className="slides"
      role="group"
      aria-roledescription="carousel"
      aria-label={labels.region}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={() => setPaused(false)}
      onKeyDown={(e) => {
        if (e.key === "ArrowRight") take(index + 1);
        if (e.key === "ArrowLeft") take(index - 1);
      }}
      onPointerDown={onPointerDown}
      onPointerUp={onPointerUp}
      onPointerCancel={() => (swipeFrom.current = null)}
    >
      <div className="slides-frame">
        {SLIDES.map((slide, i) => (
          <figure
            key={slide.id}
            className="slide"
            // `inert` rather than display:none: the images stay laid out so the
            // frame keeps one height and the page does not jump between slides
            // of different aspect ratios, but the hidden ones are out of the
            // tab order and invisible to a screen reader.
            data-active={i === index}
            inert={i !== index}
            aria-hidden={i !== index}
          >
            {/* A button, not an onClick on the image: this is a real control
                and it has to be reachable by keyboard and announced as one. */}
            <button
              type="button"
              className="slide-open"
              aria-label={labels.enlarge}
              onClick={() => setOpen(true)}
            >
              <Image
                src={slide.src}
                alt={captions[slide.id]}
                width={slide.w}
                height={slide.h}
                priority={i === 0}
                sizes="(max-width: 900px) 100vw, 1200px"
              />
              <span className="slide-zoom" aria-hidden="true">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                  <circle cx="11" cy="11" r="6.5" stroke="currentColor" strokeWidth="2" />
                  <path d="M15.8 15.8L21 21M11 8.5v5M8.5 11h5" stroke="currentColor"
                    strokeWidth="2" strokeLinecap="round" />
                </svg>
              </span>
            </button>
          </figure>
        ))}
      </div>

      {/* Caption first in the DOM, controls second. On a phone the bar stacks
          and this is the order it should stack in: a visitor reads what they
          are looking at before they reach for a way to move on. */}
      <div className="slides-bar">
        <p className="slides-caption" aria-live="polite">
          {captions[SLIDES[index].id]}
        </p>

        <div className="slides-controls">
          <button
            type="button"
            className="slides-arrow"
            aria-label={labels.previous}
            onClick={() => take(index - 1)}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="M15 5l-7 7 7 7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>

          <div className="slides-dots">
            {SLIDES.map((slide, i) => (
              <button
                key={slide.id}
                type="button"
                className="slides-dot"
                aria-label={captions[slide.id]}
                aria-current={i === index}
                data-active={i === index}
                onClick={() => take(i)}
              />
            ))}
          </div>

          <button
            type="button"
            className="slides-arrow"
            aria-label={labels.next}
            onClick={() => take(index + 1)}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="M9 5l7 7-7 7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        </div>
      </div>

      {/* Rendered always, shown via showModal(). The full-resolution source is
          only requested once `open` is true, so the hero still ships the small
          image and nobody pays 116 KB for a screenshot they never enlarge. */}
      <dialog ref={dialogRef} className="lightbox" aria-label={labels.enlarge}>
        {open && (
          <div className="lightbox-inner">
            <div className="lightbox-bar">
              <p className="lightbox-caption">{captions[SLIDES[index].id]}</p>
              <button
                type="button"
                className="lightbox-btn"
                aria-label={zoomed ? labels.zoomOut : labels.zoomIn}
                aria-pressed={zoomed}
                onClick={() => setZoomed((z) => !z)}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <circle cx="11" cy="11" r="6.5" stroke="currentColor" strokeWidth="2" />
                  <path d="M15.8 15.8L21 21" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                  <path d={zoomed ? "M8.5 11h5" : "M11 8.5v5M8.5 11h5"} stroke="currentColor"
                    strokeWidth="2" strokeLinecap="round" />
                </svg>
              </button>
              <button
                type="button"
                className="lightbox-btn"
                aria-label={labels.close}
                onClick={() => setOpen(false)}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2"
                    strokeLinecap="round" />
                </svg>
              </button>
            </div>

            <div ref={stageRef} className="lightbox-stage" data-zoomed={zoomed}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={SLIDES[index].full}
                alt={captions[SLIDES[index].id]}
                onClick={() => setZoomed((z) => !z)}
              />
            </div>

            <div className="lightbox-nav">
              <button
                type="button"
                className="lightbox-btn"
                aria-label={labels.previous}
                onClick={() => take(index - 1)}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path d="M15 5l-7 7 7 7" stroke="currentColor" strokeWidth="2"
                    strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
              <span className="lightbox-count">
                {index + 1} / {SLIDES.length}
              </span>
              <button
                type="button"
                className="lightbox-btn"
                aria-label={labels.next}
                onClick={() => take(index + 1)}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path d="M9 5l7 7-7 7" stroke="currentColor" strokeWidth="2"
                    strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
            </div>
          </div>
        )}
      </dialog>
    </div>
  );
}
