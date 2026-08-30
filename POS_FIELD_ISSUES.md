# Field test — Verteda POS, Test server

Rounds 1 and 2 are closed. **Two things are left**, and they are related: one of
them can make the other look broken when it is not.

Status: `TODO` · `WIP` · `DONE`

---

## Open

| # | Issue | Status |
|---|---|---|
| I1 | **Customer display** does nothing. POS settings offered COM10 while Windows only has COM1–COM5 and LPT1. | FIXED IN CODE — needs a test on the real till |
| I2 | A new version is installed but **the fixes are not in the app**. | NEEDS A DIAGNOSIS ON THE TILL |

---

### I1 — customer display / the COM port that does not exist

**Fixed in code; never tested on your hardware.** Three separate things were
wrong, and the first two are why it looked like a hardware fault:

* **The port list was invented.** The picker offered a hardcoded COM1–COM10
  regardless of what the machine had, so a till whose Windows only has COM1–COM5
  could sit configured on COM10, writing to nothing, forever. It now enumerates
  the ports the machine actually has (`libserialport`) and appends **LPT1–LPT3**
  by hand — a pole display on a parallel port is still a display, and
  `libserialport` only enumerates serial devices. A saved port that is currently
  unplugged is folded back in, so opening Settings never silently resets your
  choice.
* **The Test button always claimed success.** It wrote and then announced
  "sent" unconditionally, so the commonest setup mistake in the world — the
  wrong COM port — was indistinguishable from a working display. It now reports
  the real failure: which port, and that something else may be holding it open.
* **`mode` was run against LPT.** `mode LPT1: BAUD=…` is an error, and it ran
  before every single write — so a *working* parallel display was turned silent
  by its own configuration step. LPT ports are now left alone.

**On the till:** Settings → Customer Display → pick the port that is actually in
Device Manager → **Test**. If nothing appears, the message now tells you why;
send it to me verbatim. ⚠️ Do this on a build that contains the fix — see I2.

### I2 — "I installed the new version and the fixes are not there"

Not one bug but a question with three possible answers, and it has bitten twice
already (Windows on 2026-08-16, and the tablets run an old APK to this day).

**Answer it before reporting anything else as broken**, because a stale install
makes every fix in this file look like it failed:

1. **Ask the app what it is.** Settings → About shows the running version —
   read out of the bundle by `PackageInfo`, not a string someone typed, so it
   cannot flatter you. Today's source is **1.0.8+11**. If About says less than
   the release you installed, the app on screen is not the app you installed.
2. **Ask Windows what it has.** Check the date on
   `C:\Program Files (x86)\Octopus POS\pos_app.exe`. Last time this happened the
   installed exe was **two days older** than the build being tested — the
   installer had not replaced a running executable, and Windows said nothing.
   Close the POS completely (check Task Manager) before installing.
3. **Ask which app you opened.** A second copy — a desktop shortcut to an old
   build folder, or a `flutter run` build left in `build\windows\` — will happily
   run beside the installed one.

🚨 **The tablets are a known case of this**, not a mystery: `flutter build apk`
is blocked on this machine (needs JDK 21, see backlog 14), so every Android
device is running an old APK by definition. Check the APK date before reporting
an Android bug.

---

## Closed

**Round 1 (v1.0.6):** A1 A2 A3 A5 A6 A7 · B1 B2 · C1 · D1 · E1 E2 · F1.
Alongside F1: the cross-tenant `companyId` hole (closed globally by
`CompanyScopeFilter`), the control-plane lockdown (`[ControlPlane]`), and the
dashboard deploy that never fired (a case-sensitive path filter).

**Round 2 (v1.0.6 → 1.0.8):** A4 (large company name when there is no logo, plus
a **Remove logo** button so the state is reachable at all) · B1b (the Z-report
dialog now renders the opening float) · G1 (coloured session buttons, Close
Register in the till header, show/hide switches) · H1 (no unasked Z-report
modal) · H2 (Print reports its real error instead of failing silently) · H3
(`z_reports.openingCash`, so the report is self-describing wherever it is opened
from) · H4 (`ref.watch` in a callback — the reason A1 landed and its twin A2 did
not).

⚠️ Two carry-overs from those fixes, both by design: Z-reports generated
**before** H3 stay null and print without the opening-cash line, and the line is
hidden entirely on a company-wide report, where there is no single session and
therefore no single float to show.

The full reasoning for each is in `handoff.md`; it is not repeated here.
