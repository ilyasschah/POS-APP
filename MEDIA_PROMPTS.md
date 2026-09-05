# Media prompts — Gemini (image + Veo) and ElevenLabs

**Written:** 2026-09-05 · Replaces the Higgsfield route in
`PLAN_branding_and_higgsfield.md` §4. Same brief, different tools.

---

## 0. The one rule: never let AI draw your UI

Veo and Gemini will happily invent a point-of-sale interface. It will look
plausible and it will not be your app. Two reasons not to ship that:

1. `website/DESIGN.md` §8 already forbids invented customers, logos and metrics.
   An invented *product* is the same promise broken, and worse.
2. Someone books a demo off that image and sees a different application.

So split the work:

| AI generates | You supply |
|---|---|
| The room, the counter, the hands, the light, the moment the network dies | **Every pixel of screen content** |

Every prompt below therefore specifies a **dark, empty screen**. The shipped
hero already does this and it costs nothing — an unlit terminal reads as an
unlit terminal.

> **There are still no product screenshots.** Nothing on the site shows the
> actual application. §8 is the capture list.

---

## 1. What the site actually needs

| # | Asset | Where it goes | Tool | State |
|---|---|---|---|---|
| 1 | Hero scene, 16:9 | `hero-art` in `app/page.tsx` | Gemini | ✅ **shipped** — `hero-counter.webp` |
| 2 | Stock manager | Features or a new section | Gemini | §3.1 |
| 3 | Happy client | Features or a new section | Gemini | §3.2 |
| 4 | Manager + dashboard | Platforms — owner dashboard card | Gemini | §3.3 |
| 5 | Real app screenshots | Platforms cards | **The app** | §8 — blocked on you |
| 6 | "Offline-first" film | `#demo`, beside `PosDemo` | Veo + ElevenLabs | §4 — see the warning there |

The hero is done and it set the style, so #2–4 are now a matching exercise
rather than an exploration. Do them as **one batch** with the reference attached
(§2) — a set generated in one sitting holds together; one generated a week apart
does not.

---

## 2. The style is now fixed by `hero-counter.webp`

The hero is no longer a plan — it exists, it shipped, and it settles the art
direction. **Everything else must match it**, so the earlier "documentary
product photography" brief is dead; a photo-real image next to this one would
look like two different companies.

What the hero actually is, read off the file:

| | |
|---|---|
| **Medium** | Flat vector illustration, cel-shaded. No gradients, no texture, no photographic depth |
| **Line** | Bold black outline of varying weight around every object |
| **Figure** | A **featureless white figure** — round blank head, no face, no eyes, no mouth, simple tube limbs, mitten hands |
| **Wardrobe** | Deep red apron — and now a closer match than before: the brand moved to a blood red `#A4161A`, which is nearer the apron in these illustrations than the coral ever was |
| **Palette** | Cream and warm beige walls · charcoal counter · black background objects · one red · grey empty screens |
| **Light** | Soft directional sun from the left, flat plant shadows cast on the wall |
| **Screens** | Dark, flat, **empty** |
| **Ratio** | 16:9 |

### 🚨 The single most useful thing you can do

**Attach `website/assets-src/hero-counter.png` to the prompt as a reference
image and tell Gemini to match it.** Text alone will not reproduce this style —
you will get four illustrations that are each fine and obviously unrelated.
Every prompt below assumes the reference is attached.

> Note: image prompts go to **Gemini**, not ElevenLabs. ElevenLabs is
> audio-only — voice and sound effects, §5.

### The shared block

Paste this above each scene prompt:

```
Match the attached reference image EXACTLY in style: flat vector illustration,
cel-shaded, bold black outlines of varying weight, no gradients, no texture, no
photorealism.

Characters are FEATURELESS WHITE FIGURES — round blank heads, no face, no eyes,
no mouth, simple tube limbs, mitten hands — exactly as in the reference.

Palette: cream and warm beige walls, charcoal work surfaces, black background
equipment, one deep red accent, grey screens. Soft directional sunlight from the
left casting flat plant shadows.

All screens are DARK, FLAT AND EMPTY. 16:9 landscape.

NO text, NO numbers, NO logos, NO readable interface, NO facial features.
```

The faceless figure is doing real work here. It is why this set can show people
without a single stock-photo smile, and it is why `DESIGN.md` §8's ban on
invented customers survives an image with a customer in it — nobody can mistake
a blank white figure for a real person's testimonial.

---

## 3. Gemini — the three new scenes

### 3.1 Stock manager

```
[shared block]

A stockroom behind a small restaurant. A featureless white figure in a deep red
apron stands centre-left, holding a tablet in one hand at chest height and
reaching toward a shelf with the other. The tablet screen is dark and empty.

Behind and around: metal shelving racks in charcoal, stacked cardboard boxes and
crates in warm beige, a few sacks, a stepladder folded against the right wall. A
handheld barcode scanner rests on a low crate in the foreground.

Warm sunlight enters from a high window on the left, casting a flat angular
shadow across the shelving. Cream walls, charcoal shelves, one red accent on the
apron and the scanner's grip.

16:9. Figure occupies the left third, shelving fills the right two-thirds.
```

### 3.2 Happy client

```
[shared block]

The same café counter as the reference, seen from the CUSTOMER side. A
featureless white figure stands at the counter in casual clothes — no apron —
having just been served. Their posture is relaxed and open: weight on one leg,
shoulders down, one hand lifting a paper cup, the other holding a small receipt.

Across the counter, a second featureless figure in a deep red apron leans
slightly forward, one hand still resting near the terminal. The terminal screen
is dark and empty, seen from behind at an angle.

Warm sunlight from the left, flat plant shadows on the cream wall behind.
Charcoal counter, red apron, a red folded cloth, glasses stacked at the right.

16:9. The two figures face each other across the counter with clear space
between them.
```

**On "happy" with no face.** This is the constraint that makes the set work
rather than a problem to solve — the warmth has to come from *posture*, so the
prompt asks for relaxed shoulders, weight on one leg, an open stance and the
small ceremony of the handover. Do not ask for a smiley face or a `:)` on the
blank head; it will look like a mascot and it will break the set.

### 3.3 Manager checking the dashboard

```
[shared block]

A small back office after closing. A featureless white figure sits at a plain
desk in a shirt with sleeves rolled — no apron — leaning slightly toward an open
laptop, one hand on the trackpad, chin tilted down in concentration.

On the laptop screen: only three simple flat vertical bars and one rising line,
drawn as ABSTRACT SHAPES in deep red on dark grey. No text, no numbers, no
interface panels, no menus, no icons.

On the desk: a closed ledger, a glass of mint tea on a small saucer, a phone
face-down, a single desk lamp casting warm light from the right. A window at the
left shows a dark evening street.

Cream walls, charcoal desk, one red accent. 16:9, figure left of centre, desk
running to the right edge.
```

**Why this one gets shapes on the screen and the others do not.** Everywhere
else the rule is a dark empty screen, because a generated interface would be a
fake of your product (§0). Three flat cartoon bars in an obviously-illustrated
world are not pretending to be a screenshot — they read as *"a chart"* the way a
speech bubble reads as *"talking"*. Keep it to bars and a line. The moment it
sprouts panels, sidebars or numbers it has become a fake UI, and it goes back to
being empty.

### 3.4 Settings

- **Attach the reference every time.** This is worth repeating because it is the
  whole game.
- **16:9** for all three, to match the hero.
- Generate 4 variants each, pick one. Do not mix a "nearly right" one into the
  set — a broken outline weight is visible instantly when they sit in a row.
- Export, then convert before committing:
  ```
  python -c "from PIL import Image; Image.open('in.png').save('out.webp','WEBP',quality=85,method=6)"
  ```
  The hero went 1.41 MB PNG → **72 KB WebP** that way, with no visible loss on
  flat art. A 1.4 MB hero with `priority` set would have been an LCP problem on
  a phone.
- Heavy originals go in `website/assets-src/` (git-ignored). Only the WebP ships.

---

## 4. Veo — the offline-first film

The pitch is *"pull the cable mid-sale and it keeps selling."* It is far better
shown than written, which is why this is the one asset worth real effort.

### ⚠️ Decide the register before you generate a frame

**These shot prompts are photoreal, and the stills are now flat illustration.**
That was fine when the hero was a plan; it is a live conflict now. Three ways
out, and it is worth choosing deliberately:

| Option | Verdict |
|---|---|
| **Photoreal film, illustrated stills** | Defensible — illustration explains, film proves. Many products do exactly this. But it only works if the film looks *shot*, not rendered; a half-real render beside flat art looks like a mistake |
| **Animate the illustration style** | The most on-brand, and the hardest. Veo will not hold a custom faceless character across five shots. Realistically this is a motion-design job, not a prompt |
| **No film yet** | Cheapest. The `#demo` section already has `PosDemo`, a working interactive till — arguably a better proof than any video |

**My recommendation: finish the still set first, then look at the page.** With
four illustrations and real screenshots in place, the film may turn out to be
solving a problem the page no longer has.

Veo generates in short clips, so this is **five shots** cut together. Generate
each separately, in order, and stop early if the look is not holding.

**Shot 1 — the rush**
```
Handheld, slight movement. A busy café counter during evening service. A hand
enters frame and taps a countertop touch terminal twice, confident and quick.
Warm interior light, people out of focus behind. The screen is angled away from
camera and never legible. 8 seconds, no camera flourish, no zoom.
```

**Shot 2 — the cut**
```
Static close shot, low angle. Behind the counter, a network cable is pulled from
a small router. The link light goes dark. Shallow depth of field, cool shadow,
one warm coral highlight from off-screen. 8 seconds. No people, no faces.
```

**Shot 3 — nothing happens**
```
The same hand as shot 1, same counter, continuing to work without pause. A
thermal receipt printer feeds a receipt and the hand tears it off. Steady,
unhurried. The terminal screen stays angled away and unreadable. 8 seconds.
```

**Shot 4 — the kitchen still hears it**
```
Across the room, a wall-mounted display above a kitchen pass. Steam rises. A
cook reaches up and taps it once. Screen not legible to camera. Warm service
light, deep background shadow. 8 seconds.
```

**Shot 5 — reconnect**
```
Return to the router from shot 2. A hand pushes the cable back in. The link
light comes on and settles to steady. Hold on it. 8 seconds, static, quiet.
```

### Editing notes

- **Cut on action**, not on the beat of the voice. Shot 2 should land like a
  small shock — no music swell under it.
- **Shots 3 and 4 are where a real screen recording goes** if you composite.
  They are framed to make that optional rather than required.
- `DESIGN.md` §8 says **no autoplaying video.** Ship a poster frame with a play
  control. Shot 2's dark router is the strongest poster.
- Veo output carries SynthID watermarking, and commercial-use terms differ by
  Google tier. **Check yours before this goes on a commercial site.**

---

## 5. ElevenLabs — voice and sound

Free tier is roughly 10,000 credits a month, which is far more than this needs.
Two things to check before shipping: the free tier's **commercial-use terms
generally require attribution**, and a marketing site is commercial use. Confirm
on your account rather than taking this document's word for it.

### 5.1 The script

Forty seconds, five shots. The last line is the site's own `<h1>`, so the film
and the page close on the same sentence.

```
Friday. Half past seven. The room is full.

                                        [beat — shot 2, the cable]

Then the line goes down.

And nothing happens.

Every sale was already written to the terminal in front of you.
Not to a server somewhere. To the till.

Orders keep reaching the kitchen. Receipts keep printing.
The queue keeps moving.

When the connection comes back, it drains on its own.

Octopus POS. The till doesn't stop when the internet does.
```

**Direction:** unhurried, low, close-mic. This is a person explaining something
they are certain about — not an advertisement. The line *"And nothing happens"*
is the whole pitch; let it sit, do not sell it.

### 5.2 Voice settings

| Setting | Value | Why |
|---|---|---|
| Stability | ~50 | Lower drifts theatrical; higher goes flat |
| Similarity | ~75 | — |
| Style exaggeration | **0–15** | The default oversells. This is the setting that ruins it |
| Speaker boost | on | — |

Pick a **calm mid-range voice**, and audition it against room tone before
committing — a voice that sounds warm in isolation often sounds like an
infomercial over a busy café.

### 5.3 Sound effects

Generate these separately in ElevenLabs Sound Effects and mix under the VO:

- `quiet café room tone, evening, distant cutlery and low conversation, no music` — bed, low
- `thermal receipt printer feeding and cutting a receipt, close, mechanical` — shot 3
- `a single soft confirmation tone from a payment terminal` — shot 1, once only
- `a small plastic network cable connector clicking into a socket` — shot 5

**No music.** The room tone is the score. A music bed is what makes this look
like every other POS ad.

---

## 6. Where the files land

| Asset | Destination | Committed? |
|---|---|---|
| Hero + 4 platform stills | `website/public/` | ✅ yes — they are small |
| The film (`.mp4`) | **Server or CDN, not this repo** | ❌ **no** |
| Poster frame (`.webp`) | `website/public/` | ✅ yes |

`.git` is already 293 MB (audit H2) and only stopped growing this session. A
40-second 1080p file would undo that. The site deploys to IIS —
`website/public/web.config` — so drop the `.mp4` beside the built site on the
server and reference it by URL.

If you do want it in `public/` for local dev, add `website/public/*.mp4` to
`.gitignore` **first**.

---

## 7. Order of work

1. Hero image. **Stop and look at it on the real page** before generating
   anything else — on `#FFFFFF` and `#FDF3F5`, at 1440px and at 390px.
2. The four platform stills, as one batch, same framing.
3. Real screenshots from the app. Without these the site still shows no product.
4. The five Veo shots.
5. VO and SFX.
6. Cut, poster frame, host, wire up with a play control.

Steps 1–2 are cheap and reversible. Step 4 is the one with a quota — do not
start it until step 1 has told you the look is right.

---

## 8. Real screenshots — what to capture

**Yes, please.** Nothing on the site currently shows the application, and no
prompt can fix that honestly. Six captures, in priority order.

### The rules that apply to all six

1. **Seed data only.** No real customer names, no real takings, no real phone
   numbers. The site is public; a screenshot is a data leak with a nice frame.
   Invent a menu — the demo section already uses Espresso / Croissant / Burger /
   Salad / Lemonade / Cheesecake, so reusing those makes the page feel coherent.
2. **Theme: `dimmed` or `dark`.** The site is light with a dark footer band, and
   the hero illustration has a dark screen. Dark captures sitting in white cards
   will look deliberate; light captures will muddle into the page.
3. **Accent: the brand coral.** It is the default now, but check Settings — an
   install predating the rollout may still carry blue, and a blue screenshot on
   a coral site is the one mistake nobody will forgive.
4. **Language: English**, since the crawled copy is English. If it is cheap, do
   #1 in Arabic too — a genuine RTL screenshot is a stronger proof of the
   trilingual claim than the sentence making it.
5. **No OS chrome.** No taskbar, no window title bar, no notification badges,
   no clock showing 3am. Capture the app's client area only.
6. **PNG at native resolution.** I will convert and size them.

### The list

| # | Screen | What must be visible | Why it earns a place |
|---|---|---|---|
| 1 | **Windows till, mid-sale** | 3–4 lines in the cart, a running total, the keypad | The main event — the counter experience |
| 2 | **The same till, OFFLINE** | The offline/queued indicator, cart still usable | ⭐ **The most valuable image on the site.** It is the entire pitch in one frame, and it is the one thing a competitor's screenshot cannot show |
| 3 | **Kitchen display** | 3–4 live tickets at different states | Backs the "kitchen keeps running on the shop LAN" claim |
| 4 | **Android tablet** | The same app, table-side, portrait or landscape | Proves "same app, two targets" — take it on the real 13" tablet, not a resized desktop window |
| 5 | **Stock / split sourcing** | One cart, two warehouses on different lines | The genuine differentiator in the feature grid, and the hardest to believe from text alone |
| 6 | **Owner dashboard** | Takings and a trend chart | Fills the fourth platform card |

**If you only do two, do #1 and #2.** Everything else on the page is a claim;
those two are evidence.

### Where to put them

Drop the PNGs in `website/assets-src/` — it is git-ignored, so nothing heavy
reaches the index. Tell me they are there and I will convert, size, frame them
in the Platforms cards, and write the alt text in all three languages.
