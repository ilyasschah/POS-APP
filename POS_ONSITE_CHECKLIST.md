# Octopus POS — On-Site Commissioning Checklist

**Terminal:** Verteda POS (Windows 10 22H2)
**Peripherals:** 240-LCM customer pole display (P/N ARTJ-00371) · WD8260 80 mm receipt printer with cash drawer on its RJ11 port · ZKB103 barcode scanner
**Backend:** **PRODUCTION** — `https://api.octopus-pos.com/api`
**Date:** ____________  **Done by:** ____________

---

## 0 · Windows prerequisites (before installing the app)

- [ ] `winver` shows **Windows 10 22H2** (build 19045). Anything below 1703 has no `icu.dll` and the app will not start.
- [ ] Windows Update finished, machine rebooted, no pending restart.
- [ ] **64-bit** Windows (`Settings → System → About → System type`).
- [ ] Delete any `icu.dll` you manually dropped into `C:\Windows\System32` while troubleshooting — wrong bitness, and it causes `0xc000007b`.
- [ ] Correct **date, time, time zone, region** (receipts, shifts and Z-reports are stamped from this).
- [ ] Power plan: **never sleep, never hibernate, display never off** (`Control Panel → Power Options`). Disable **USB selective suspend** — it kills the scanner and pole display mid-shift.
- [ ] Screen resolution ≥ 1280×768, scaling 100 % (125 % max), landscape.
- [ ] Windows account is **Administrator** for the install; set auto-login if the till must boot unattended.
- [ ] Antivirus exclusion for the install folder.

## 1 · Install

- [ ] Run `Octopus_POS_Setup_v<version>.exe` **as Administrator**.
- [ ] Let it install **VC_redist.x64.exe**. If it errors, install it manually and re-run setup — a failed redist gives the same `0xc000007b`.
- [ ] Desktop / Start-menu shortcut created; app launches to the master-login screen.
- [ ] Installed version noted: ____________ (must match Settings → About).

## 2 · Point the terminal at the TEST server ⚠️

> The shipped build's compiled default is now **Production**, so a fresh install
> points at the right server with nothing to configure. Still verify it below: a
> terminal left on the wrong endpoint logs in "fine" and then reports another
> tenant's subscription state. (Until the production cutover the compiled default
> was the **Dev** Tailscale address, which no till could reach at all.)

- [ ] On the **master login** screen, the environment segmented control is set to **Production**.
- [ ] Verify after login: `Settings → Connection → API base URL` = `https://api.octopus-pos.com/api`.
- [ ] Master login with the production credentials succeeds.
- [ ] The company shown is **the correct customer company** — not a leftover demo tenant.
- [ ] `Settings → Subscription`: lease **active**, expiry date sensible.
- [ ] Device **seat** consumed correctly — seat count went up by exactly 1.

## 3 · Users & login

- [ ] Cashier PIN/user login works after master login.
- [ ] Permissions correct for the test cashier (refund, void, drawer-open, reports).
- [ ] Sign-out → sign-in round-trip works and does **not** leak a second seat.

## 4 · Receipt printer (WD8260, 80 mm)

- [ ] Manufacturer Windows driver installed; printer visible in `Settings → Printers & scanners`.
- [ ] Rename the Windows queue to something stable, e.g. `WD8260` — the app stores the **queue name**, so renaming it later breaks printing.
- [ ] Windows **test page** prints (paper feeds, no error light).
- [ ] Driver preferences: paper width **80 mm** (80 × 297 mm or Roll 80 mm).
- [ ] In the app, `Settings → Printers → Receipt`:
  - [ ] Printer name = the Windows queue.
  - [ ] Paper size **80 mm**, copies, margins.
  - [ ] Header / footer (company name, address, VAT/ICE, thank-you line).
  - [ ] **Test print** → clean receipt, right edge not clipped, Arabic/French characters render.
- [ ] If a kitchen printer is in scope: repeat for `Kitchen ticket` and set its printer **group** routing.

## 5 · Cash drawer (RJ11 into the WD8260)

- [ ] Drawer cable in the printer's **DK / RJ11** port (not the network port).
- [ ] `Settings → Printers → Receipt → Cash drawer`:
  - [ ] **Enabled** = on.
  - [ ] Transport = **Printer** (kick is sent to the Windows queue as a RAW job).
  - [ ] Kick command = default `\x1B\x70\x00\x19\xFA` (decimal `27,112,0,25,250`). If nothing happens, try pin 5: `\x1B\x70\x01\x19\xFA`.
- [ ] **Test drawer open** → drawer physically pops.
- [ ] Drawer opens automatically on a **cash** payment (payment type has *open cash drawer* ticked).
- [ ] Drawer does **not** open on a card payment.

## 6 · Customer pole display (240-LCM, serial)

- [ ] Display powered and connected; if USB, its **USB-to-serial driver** is installed.
- [ ] `Device Manager → Ports (COM & LPT)` — port noted: **COM____**
- [ ] `Settings → Customer display`:
  - [ ] **Enabled** = on.
  - [ ] Port = the COM number above (COM10+ is handled automatically).
  - [ ] Baud **9600**, Data bits **8**, Parity **None**, Stop bits **1**, Flow control **None** — use *Restore defaults*, then match the display's DIP switches / manual.
  - [ ] Characters per line = **20** (16 if the panel is 2×16).
  - [ ] Welcome message lines entered.
- [ ] **Test display** → welcome text appears, no garbage characters.
  - Garbage = wrong baud rate. Nothing at all = wrong COM port, or another program is holding the port.
- [ ] Ring up an item and open payment → display shows **TOTAL DUE** + amount.
- [ ] Close payment → display returns to the welcome message.

> Expected scope: this display shows the welcome message and the total due at payment — it is not an itemised customer screen. For a live cart view, use `Settings → Customer display → Web display` on a second monitor or tablet (`http://<till-ip>:8181`).

## 7 · Barcode scanner (ZKB103)

- [ ] Plugged into USB, enumerates as a **HID keyboard** (no driver needed).
- [ ] Scanner in **USB keyboard-wedge** mode with a **CR / Enter suffix** — scan the config barcodes in its manual if not.
- [ ] Scanner keyboard layout = **US / English**. A French/AZERTY mismatch scrambles digits.
- [ ] Notepad test: scan a product barcode → digits exactly right, cursor jumps to a new line.
- [ ] In the app, scan **with the search box focused** → product added.
- [ ] In the app, scan **with nothing focused** → product still added (global scan listener).
- [ ] Scan an unknown barcode → clean "not found" message, no crash.
- [ ] Codes shorter than 4 characters are ignored by design — do not test with a 3-digit label.
- [ ] If weight-embedded / nomenclature barcodes (scale labels) are used: configure the rules, scan one → correct product **and** correct weight/price.

## 8 · Business smoke test (on the test company)

- [ ] Open a **shift / cash session** with a starting float.
- [ ] Products, categories, prices load from the test server; images render.
- [ ] Cart: quantity change, discount, modifier, note, remove line.
- [ ] **Cash** payment → receipt prints, drawer opens, change screen correct.
- [ ] **Card / other** payment → receipt prints, drawer stays shut.
- [ ] Split / partial payment.
- [ ] **Refund** an order → stock returns, receipt prints, permission enforced.
- [ ] **Void** a line and a whole order with a void reason.
- [ ] Stock deducted from the right **warehouse** (item-level sourcing) — verify one line on the server.
- [ ] Out-of-stock product → interactive dialog with fallback warehouses, **not** a crash.
- [ ] Kitchen ticket prints / reaches the KDS, if in scope.
- [ ] **X-report** and **Z-report** totals match the day's test transactions.
- [ ] Close the shift; counted cash reconciles with expected.

## 9 · Offline resilience (do this before you leave)

- [ ] Unplug the network / disable Wi-Fi.
- [ ] Take a full order and pay it → completes and prints offline.
- [ ] Reconnect → the order syncs up and appears on the server within a minute.
- [ ] Restart the app while offline → it opens and the data survives.
- [ ] `Settings → Database`: local encrypted DB present; set the **backup path** to a real folder (device-local, not synced) and run one backup.

## 10 · Stability & handover

- [ ] Full reboot → app auto-starts (if configured) and reaches login with all peripherals still working.
- [ ] Unplug/replug the scanner and pole display after the reboot → both still work.
- [ ] ~30 minutes of mixed transactions, watching for slowdowns or stray dialogs.
- [ ] Version in `Settings → About` recorded: ____________
- [ ] Auto-update check runs without error.
- [ ] Written down for the site: environment = **Test**, printer queue name, drawer transport, pole display COM port, scanner mode.
- [ ] Cashier walkthrough: login, cart, payment, refund, drawer, shift open/close, out-of-paper.

---

## Known gotchas on this build

| Symptom | Cause | Fix |
|---|---|---|
| Won't start, `icu.dll` missing | Windows older than 1703; `flutter_timezone_plugin.dll` imports the system ICU | Windows 10 22H2 (done) |
| `0xc000007b` on launch | 32-bit DLL dropped into System32, or the x64 VC++ redist missing/failed | Remove that DLL, install `VC_redist.x64.exe` |
| Logs in but wrong/expired subscription, no data | Terminal left on the **Dev** endpoint (compiled default) | Master login → **Test**; verify in Settings → Connection |
| Drawer never opens, no error shown | Wrong Windows queue name, or drawer on pin 5 | Test-drawer button; try `\x1B\x70\x01\x19\xFA` |
| Pole display shows garbage | Baud mismatch | 9600 8-N-1; check the display's DIP switches |
| Scanned digits wrong | Scanner / Windows keyboard-layout mismatch | Set the scanner to US keyboard |
| App reaches the server but "subscription expired" | Seat cap reached or wrong tenant | Settings → Subscription; release a seat by signing out on the old device |
