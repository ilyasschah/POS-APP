#!/usr/bin/env python3
"""Builds `website/public` from `website/assets-src`.

    python tools/generate_site_media.py

`assets-src` holds the ORIGINALS — full-resolution captures of the running app
and the role illustrations. `public` holds only what the browser downloads:
WebP, sized to what the layout actually renders. Nothing in `public` should be
hand-placed, and the two drifted apart once already (new blue-themed captures
were dropped into `assets-src` while `public` kept serving the old red ones),
which is why this exists.

Two sizes per screenshot:
  <name>.webp        what the hero carousel shows
  <name>-full.webp   what the lightbox shows at 1:1, for reading actual pixels

Requires node + sharp — `npm install` in `website/`. sharp's WebP encoder is
meaningfully better than Pillow's at these sizes, and the site already depends
on it.

⚠️ The `w`/`h` in `app/components/HeroSlides.tsx` must match the sizes this
writes. They are the intrinsic ratio Next reserves space from, so a mismatch
reflows the hero on load. This script prints them.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "website"
SRC = SITE / "assets-src"
OUT = SITE / "public"
SHARP = SITE / "node_modules" / "sharp"

# Hero screenshots: source -> public basename. Rendered at the source's own
# aspect ratio; never upscaled past the source's own width.
SCREENSHOTS = {
    "mid_sale.jpg": "mid_sale",
    "dashboard.webp": "dashboard",
    "sales_history.jpg": "sales_history",
    "customer_display.jpg": "customer_display_web",
}
CAROUSEL_WIDTH = 1600
LIGHTBOX_WIDTH = 2600

# Role illustrations: source -> public basename. Fixed box, cropped to fill,
# because the four sit in a grid and a ragged row of heights looks broken.
ROLES = {
    "Manager Checking the Dashboard.jpeg": "role-owner",
    "stock manager.jpeg": "role-stock",
    "happy client.jpeg": "role-customer",
    "hero-counter.png": "role-till",
}
ROLE_BOX = (1200, 670)

NODE_SCRIPT = """
const sharp = require(process.argv[1]);
const job = JSON.parse(process.argv[2]);
(async () => {
  const out = [];
  for (const t of job) {
    let p = sharp(t.src);
    const meta = await p.metadata();
    if (t.fit === 'cover') {
      p = p.resize(t.w, t.h, { fit: 'cover', position: 'centre' });
    } else {
      // withoutEnlargement: a 917px-wide capture must not be blown up to
      // 2600px. It comes back at its own size and the manifest reports that,
      // so the markup can carry the real dimensions.
      p = p.resize({ width: t.w, withoutEnlargement: true });
    }
    const info = await p.webp({ quality: t.q, effort: 6 }).toFile(t.dest);
    out.push({ dest: t.dest, w: info.width, h: info.height, bytes: info.size,
               srcW: meta.width, srcH: meta.height });
  }
  process.stdout.write(JSON.stringify(out));
})().catch(e => { console.error(e.message); process.exit(1); });
"""


def main() -> int:
    if not SHARP.is_dir():
        print(f"sharp not found at {SHARP}\nRun `npm install` in website/ first.",
              file=sys.stderr)
        return 1

    jobs = []
    for name, base in SCREENSHOTS.items():
        src = SRC / name
        if not src.is_file():
            print(f"  missing source: {name}", file=sys.stderr)
            continue
        jobs.append({"src": str(src), "dest": str(OUT / f"{base}.webp"),
                     "w": CAROUSEL_WIDTH, "q": 72, "fit": "inside"})
        jobs.append({"src": str(src), "dest": str(OUT / f"{base}-full.webp"),
                     "w": LIGHTBOX_WIDTH, "q": 78, "fit": "inside"})

    for name, base in ROLES.items():
        src = SRC / name
        if not src.is_file():
            print(f"  missing source: {name}", file=sys.stderr)
            continue
        jobs.append({"src": str(src), "dest": str(OUT / f"{base}.webp"),
                     "w": ROLE_BOX[0], "h": ROLE_BOX[1], "q": 74, "fit": "cover"})

    OUT.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["node", "-e", NODE_SCRIPT, str(SHARP), json.dumps(jobs)],
        check=True, capture_output=True, text=True,
    )
    results = json.loads(proc.stdout)

    for r in results:
        rel = Path(r["dest"]).relative_to(SITE)
        print(f"  {rel}  {r['w']}x{r['h']}  {r['bytes'] / 1024:.0f} KB")

    print("\nHeroSlides.tsx must carry these (carousel sizes):")
    for base in SCREENSHOTS.values():
        hit = next((r for r in results
                    if Path(r["dest"]).name == f"{base}.webp"), None)
        if hit:
            print(f"  {base:22s} w: {hit['w']}, h: {hit['h']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
