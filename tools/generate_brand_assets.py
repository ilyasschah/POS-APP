#!/usr/bin/env python3
"""Regenerates every app icon in the ecosystem from the master mark in `img/`.

    python tools/generate_brand_assets.py

The hand-drawn sources are two files in `img/`:

    icon.svg       the mark ON its rounded plate  — what a launcher shows
    icon-mark.svg  the mark ALONE, transparent    — for grounds we do not own

The Kitchen Display has its own pair, icon-kds.svg / icon-kds-mark.svg, but
those are GENERATED from the two above by generate_kds_mark.py, which this
script runs first.

Everything else in this repo that shows the octopus is a DERIVATIVE and is
overwritten by this script. Nothing here should ever be hand-edited: if the
brand changes, change the two SVGs and run this.

Prerequisites
-------------
* Pillow                       — compositing, resizing, .ico writing
* node + sharp, for SVG -> PNG. `sharp` ships inside the marketing site's
  dependencies (`website/node_modules`), so `npm install` in `website/` is the
  whole setup. It is the only SVG rasteriser already present in the tree.

Why three shapes rather than one
--------------------------------
* PLATED    rounded corners, transparent outside them. Desktop, favicons, and
            anywhere the icon is drawn as-is.
* OPAQUE    square, full-bleed plate, no rounding. iOS applies its OWN corner
            mask; shipping pre-rounded art there stacks two roundings and
            leaves white wedges in the corners. iOS also rejects alpha.
* MASKABLE  square, full-bleed plate, mark shrunk into the inner 80% "safe
            zone". Android crops the icon to whatever shape the launcher
            fancies — circle, squircle, teardrop — so anything outside that
            zone is not guaranteed to survive.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "img"
SHARP = ROOT / "website" / "node_modules" / "sharp"


@dataclass(frozen=True)
class Mark:
    """One app's artwork: the mark on its plate, and the mark alone."""

    plated: Path
    bare: Path


# The POS mark is the brand's. Admin portal, owner dashboard and the site use it
# too — they are all "the POS" to the people who run one.
POS = Mark(IMG / "icon.svg", IMG / "icon-mark.svg")

# The Kitchen Display gets its OWN — the octopus broadcasting, because pairing
# with a till is the first thing it does. Built by generate_kds_mark.py from
# the POS artwork at the start of every run, so it can never drift from it.
KDS = Mark(IMG / "icon-kds.svg", IMG / "icon-kds-mark.svg")

# The plate gradient, quoted from icon.svg's `plateGrad`. Kept in sync by hand:
# these two values and the SVG's two stops are the same decision written twice.
PLATE_FROM = (255, 255, 255)
PLATE_TO = (232, 243, 249)

# Fraction of the canvas the mark occupies on a maskable icon. Android's safe
# zone is the inner 80%; 76% leaves a little air so the mark never grazes the
# crop on a launcher that trims hard.
MASKABLE_INSET = 0.76

# Every .ico gets the full ladder. Windows picks per context — 16 in a title
# bar, 256 in the large-icon file view — and an .ico holding only 32 gets
# scaled up into mush at 256.
ICO_SIZES = [(s, s) for s in (16, 24, 32, 48, 64, 128, 256)]


# --------------------------------------------------------------------------- #
# Rasterising                                                                  #
# --------------------------------------------------------------------------- #

def _render(svg: Path, size: int, out: Path) -> None:
    """SVG -> PNG at `size` square, via node + sharp."""
    script = (
        "const sharp=require(process.argv[1]);"
        "sharp(process.argv[2],{density:1200})"
        ".resize(Number(process.argv[4]),Number(process.argv[4]))"
        ".png().toFile(process.argv[3])"
        ".catch(e=>{console.error(e.message);process.exit(1)});"
    )
    subprocess.run(
        ["node", "-e", script, str(SHARP), str(svg), str(out), str(size)],
        check=True,
        capture_output=True,
        text=True,
    )


def _plate(size: int) -> Image.Image:
    """The plate gradient as a full-bleed opaque square.

    Drawn per-row on the diagonal, matching the SVG's 0%,0% -> 100%,100%
    linear gradient closely enough that a plated icon and an opaque one look
    like the same artwork side by side.
    """
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    span = 2 * (size - 1) or 1
    # A 0,0 -> 100%,100% linear gradient is a function of (x + y) alone, so it
    # paints as `2 * size` diagonal lines rather than a per-pixel sweep.
    for d in range(span + 1):
        t = d / span
        colour = tuple(
            round(a + (b - a) * t) for a, b in zip(PLATE_FROM, PLATE_TO)
        )
        draw.line([(d, 0), (0, d)], fill=colour)
    return img


# --------------------------------------------------------------------------- #
# The three shapes                                                             #
# --------------------------------------------------------------------------- #

def plated(size: int, cache: dict, mark: Mark = POS) -> Image.Image:
    """Rounded plate, transparent corners — straight from the plated SVG."""
    return _from_svg(mark.plated, size, cache)


def opaque(size: int, cache: dict, mark: Mark = POS) -> Image.Image:
    """Square full-bleed plate, mark at full size, NO alpha (iOS)."""
    base = _plate(size)
    art = _from_svg(mark.bare, size, cache)
    base.paste(art, (0, 0), art)
    return base


def maskable(size: int, cache: dict, mark: Mark = POS) -> Image.Image:
    """Square full-bleed plate, mark inside Android's safe zone."""
    base = _plate(size).convert("RGBA")
    px = round(size * MASKABLE_INSET)
    art = _from_svg(mark.bare, px, cache)
    offset = (size - px) // 2
    base.paste(art, (offset, offset), art)
    return base


def _from_svg(svg: Path, size: int, cache: dict) -> Image.Image:
    key = (svg.name, size)
    if key not in cache:
        tmp = Path(cache["_dir"]) / f"{svg.stem}-{size}.png"
        _render(svg, size, tmp)
        cache[key] = Image.open(tmp).convert("RGBA")
    return cache[key].copy()


# --------------------------------------------------------------------------- #
# Targets                                                                      #
# --------------------------------------------------------------------------- #

# iOS AppIcon sets: filename suffix -> pixel size. The Flutter template names
# each slot `<points>x<points>@<scale>x`, so the pixels are points * scale.
IOS_SLOTS = {
    "20x20@1x": 20, "20x20@2x": 40, "20x20@3x": 60,
    "29x29@1x": 29, "29x29@2x": 58, "29x29@3x": 87,
    "40x40@1x": 40, "40x40@2x": 80, "40x40@3x": 120,
    "50x50@1x": 50, "50x50@2x": 100,
    "57x57@1x": 57, "57x57@2x": 114,
    "60x60@2x": 120, "60x60@3x": 180,
    "72x72@1x": 72, "72x72@2x": 144,
    "76x76@1x": 76, "76x76@2x": 152,
    "83.5x83.5@2x": 167,
    "1024x1024@1x": 1024,
}

MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def write_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}")


def write_ico(cache: dict, path: Path, mark: Mark = POS) -> None:
    """A multi-size .ico built from the plated shape."""
    path.parent.mkdir(parents=True, exist_ok=True)
    base = plated(256, cache, mark)
    base.save(path, "ICO", sizes=ICO_SIZES)
    print(f"  {path.relative_to(ROOT)}")


def copy_svg(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    print(f"  {dst.relative_to(ROOT)}")


def flutter_app(cache: dict, app: Path, *, ios_slots: dict,
                mark: Mark = POS) -> None:
    """The icon set every Flutter target in this repo shares."""
    # Web / PWA
    write_png(plated(32, cache, mark), app / "web" / "favicon.png")
    for size in (192, 512):
        write_png(plated(size, cache, mark),
                  app / "web" / "icons" / f"Icon-{size}.png")
        write_png(maskable(size, cache, mark),
                  app / "web" / "icons" / f"Icon-maskable-{size}.png")

    # Windows — also the icon both KDS/POS installers (.iss) point at.
    write_ico(cache, app / "windows" / "runner" / "resources" / "app_icon.ico",
              mark)

    # iOS — opaque, square, no alpha.
    ios = app / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if ios.is_dir():
        for slot, px in ios_slots.items():
            write_png(opaque(px, cache, mark), ios / f"Icon-App-{slot}.png")

    # macOS — keeps the rounded plate; macOS does not mask.
    mac = app / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if mac.is_dir():
        for size in MACOS_SIZES:
            write_png(plated(size, cache, mark), mac / f"app_icon_{size}.png")


def existing_ios_slots(app: Path) -> dict:
    """Only the slots this app's asset catalogue actually declares.

    The two Flutter apps were generated by different Flutter versions and have
    different slot lists; writing a file Xcode has no entry for leaves an
    orphan, and missing one leaves a hole in the catalogue.
    """
    ios = app / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if not ios.is_dir():
        return {}
    present = {p.name for p in ios.glob("Icon-App-*.png")}
    return {
        slot: px
        for slot, px in IOS_SLOTS.items()
        if f"Icon-App-{slot}.png" in present
    }


def main() -> int:
    if not SHARP.is_dir():
        print(f"sharp not found at {SHARP}\nRun `npm install` in website/ first.",
              file=sys.stderr)
        return 1

    # The KDS mark is derived from the POS one, so it is rebuilt BEFORE any
    # rendering — a redrawn octopus reaches both apps in the same run. Imported
    # here rather than at the top so a missing sibling fails loudly and late.
    from generate_kds_mark import build as build_kds_mark
    print("KDS mark")
    for svg in build_kds_mark():
        print(f"  {svg.relative_to(ROOT)}")

    with tempfile.TemporaryDirectory() as tmp:
        cache: dict = {"_dir": tmp}

        print("POS (Front-End)")
        pos = ROOT / "Front-End"
        copy_svg(IMG / "icon.svg", pos / "assets" / "icon.svg")
        write_png(plated(512, cache), pos / "assets" / "icon.png")
        write_ico(cache, pos / "assets" / "favicon.ico")
        write_ico(cache, pos / "app_icon.ico")
        flutter_app(cache, pos, ios_slots=existing_ios_slots(pos))

        print("Kitchen Display")
        kds = ROOT / "kitchen_display"
        flutter_app(cache, kds, ios_slots=existing_ios_slots(kds), mark=KDS)

        print("Admin portal (Back-End)")
        api = ROOT / "Back-End" / "Web-POS.Api"
        copy_svg(IMG / "icon.svg", api / "wwwroot" / "img" / "icon.svg")
        write_png(plated(512, cache), api / "wwwroot" / "img" / "icon.png")
        write_ico(cache, api / "wwwroot" / "favicon.ico")

        print("Owner dashboard")
        owner = ROOT / "Octopus_Dashboard" / "OwnerDashboard"
        copy_svg(IMG / "icon.svg", owner / "icon.svg")
        write_png(plated(512, cache), owner / "icon.png")
        write_ico(cache, owner / "favicon.ico")

        web = ROOT / "octopus_dashboard_web" / "web"
        write_png(plated(32, cache), web / "favicon.png")
        write_png(plated(16, cache), web / "icons" / "favicon-16.png")
        for size in (192, 512):
            write_png(plated(size, cache), web / "icons" / f"Icon-{size}.png")
            write_png(maskable(size, cache), web / "icons" / f"Icon-maskable-{size}.png")
        # iOS home screen: opaque, iOS supplies the corner mask.
        for size in (152, 167, 180):
            write_png(opaque(size, cache), web / "icons" / f"apple-touch-icon-{size}.png")

        print("Marketing site")
        site = ROOT / "website"
        write_png(plated(512, cache), site / "assets-src" / "icon.png")
        write_ico(cache, site / "app" / "favicon.ico")

        print("\nDone.")
        # Browsers key their favicon cache by URL, so new bytes at an old URL
        # never show up. The admin portal busts it by itself (asp-append-version);
        # the owner dashboard does not — see PROJECT_DOCUMENTATION.md §8.1.
        print("\nReminder: bump ?v=N in octopus_dashboard_web/web/index.html and"
              "\n  web/manifest.json, and CACHE_VERSION in web/sw.js, then run"
              "\n  `flutter build web --release` — or the dashboard tab keeps"
              "\n  showing the old icon.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
