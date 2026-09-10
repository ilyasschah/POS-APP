#!/usr/bin/env python3
"""Re-hues the RED in the marketing illustrations to octopus blue.

    python tools/recolour_brand_red.py [--check]

The four role illustrations in `website/assets-src` (`Manager Checking the
Dashboard.jpeg`, `stock manager.jpeg`, `happy client.jpeg`, `hero-counter.png`)
were drawn to the previous brand: red aprons, a red till, red accents on the
counter. Nothing else about them is wrong, so they are re-hued rather than
redrawn — the line work, the composition and the wood tones all survive.

Why a hue band and not a colour swap
------------------------------------
The illustrations are mostly WOOD and cardboard, which live at hue 20-50 and
account for ~80% of the saturated pixels. The brand red sits at 335-15. Those
two do not overlap, and there is a clean empty gap between 10 and 20 — measured,
not assumed. So the band below is safe: it catches every apron pixel and cannot
touch a crate.

The band is mapped ONTO a band rather than onto a single hue, so the shading
inside the apron stays shading instead of flattening into one flat shape.
Saturation and lightness are carried through untouched apart from the ceiling,
which exists because a fully saturated red re-hued to 199 comes out as a
fluorescent cyan that belongs to no brand at all.

`--check` writes before/after strips to the scratch directory instead of
touching the sources.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "website" / "assets-src"

TARGETS = [
    "Manager Checking the Dashboard.jpeg",
    "stock manager.jpeg",
    "happy client.jpeg",
    "hero-counter.png",
]

# The red band, in degrees, written as a continuous range through 360.
RED_FROM, RED_TO = 335.0, 375.0
# Where it lands: octopus blue's own 199, given the same width to move in.
BLUE_FROM, BLUE_TO = 189.0, 209.0
# Below this, a pixel is a neutral and its hue is noise — re-hueing it would
# tint the greys and the white line work.
MIN_SATURATION = 0.18
# A saturated red re-hued lands far brighter than the brand's own 0.59.
MAX_SATURATION = 0.62


def _rgb_to_hsl(a: np.ndarray):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    light = (mx + mn) / 2
    sat = np.where(
        d == 0, 0.0,
        np.where(light > 0.5, d / (2 - mx - mn + 1e-9), d / (mx + mn + 1e-9)),
    )
    hue = np.zeros_like(mx)
    m = (d > 0) & (mx == r)
    hue[m] = (((g - b) / (d + 1e-9))[m] % 6) / 6
    m = (d > 0) & (mx == g)
    hue[m] = ((((b - r) / (d + 1e-9)) + 2)[m]) / 6
    m = (d > 0) & (mx == b)
    hue[m] = ((((r - g) / (d + 1e-9)) + 4)[m]) / 6
    return hue * 360, sat, light


def _hsl_to_rgb(hue: np.ndarray, sat: np.ndarray, light: np.ndarray):
    h = (hue % 360) / 360
    q = np.where(light < 0.5, light * (1 + sat), light + sat - light * sat)
    p = 2 * light - q

    def channel(t):
        t = t % 1.0
        out = np.where(
            t < 1 / 6, p + (q - p) * 6 * t,
            np.where(
                t < 1 / 2, q,
                np.where(t < 2 / 3, p + (q - p) * (2 / 3 - t) * 6, p),
            ),
        )
        return np.where(sat == 0, light, out)

    return np.stack([channel(h + 1 / 3), channel(h), channel(h - 1 / 3)], axis=-1)


def recolour(img: Image.Image) -> Image.Image:
    alpha = img.getchannel("A") if img.mode in ("RGBA", "LA") else None
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    hue, sat, light = _rgb_to_hsl(a)

    # Unwrap the band: 350 stays 350, 5 becomes 365, so one comparison covers it.
    unwrapped = np.where(hue < 180, hue + 360, hue)
    hit = (unwrapped >= RED_FROM) & (unwrapped <= RED_TO) & (sat >= MIN_SATURATION)
    if not hit.any():
        return img

    t = (unwrapped - RED_FROM) / (RED_TO - RED_FROM)
    new_hue = np.where(hit, BLUE_FROM + t * (BLUE_TO - BLUE_FROM), hue)
    new_sat = np.where(hit, np.minimum(sat, MAX_SATURATION), sat)

    out = _hsl_to_rgb(new_hue, new_sat, light)
    result = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8))
    if alpha is not None:
        result.putalpha(alpha)
    return result


def main() -> int:
    check = "--check" in sys.argv
    out_dir = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else None

    for name in TARGETS:
        path = SRC / name
        if not path.is_file():
            print(f"  missing: {name}")
            continue
        img = Image.open(path)
        new = recolour(img)

        if check:
            strip = Image.new("RGB", (img.width * 2, img.height), "white")
            strip.paste(img.convert("RGB"), (0, 0))
            strip.paste(new.convert("RGB"), (img.width, 0))
            strip.thumbnail((1400, 1400))
            target = (out_dir or Path(".")) / f"check-{Path(name).stem}.png"
            strip.save(target)
            print(f"  {target}")
            continue

        new.save(path, quality=95)
        print(f"  {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
