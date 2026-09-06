/// Static data for the end-to-end integration tests.
///
/// This is the Flutter twin of `e2e/config/test-config.js`. Edit the values
/// here; the test reads nothing else from the machine.
///
/// 🚨 Unlike the Cypress config, this file IS committed — deliberately. It
/// holds no secrets: a terminal name, a throwaway PIN and two appearance
/// choices. The one real credential in this flow (the company's login) is NOT
/// here — it is read at run time from `e2e/output/pos-credentials.json`, which
/// is git-ignored because it holds plaintext passwords. Keep it that way: if
/// you ever need a real password for a test, put it in that file, not this one.
library;

/// Terminal name typed into onboarding's "Device name" field.
///
/// It is not cosmetic: this name is what the account's device list shows in the
/// admin portal, so a registered terminal reads "POS1" rather than a UUID.
const String kPosName = 'POS1';

/// The PIN the test creates for the company's first user on this device.
///
/// Must be exactly 4 digits — the pad submits automatically on the fourth
/// keystroke (`_PinPadModal._onKeyPress`), so a shorter or longer value simply
/// never completes.
const String kPosPin = '2222';

/// Onboarding's theme segment: 'light' or 'dark'.
const String kThemeMode = 'light';

/// Which accent swatch to tap, by position in onboarding's Accent row.
///
/// 0 is the brand red (#A4161A) — the octopus in assets/icon.svg and the
/// marketing site. Any index is valid; the test only asserts that a colour was
/// chosen, not which one.
const int kAccentIndex = 0;

/// Which backend the terminal registers against, by the label on the
/// master-login segmented picker: 'Dev', 'Test' or 'Production'.
///
/// 🚨 Not optional, and never leave this on Production. `AppConfig` compiles in
/// Production as the default endpoint, so a test that skipped this step would
/// register a device and burn a seat on the live system.
const String kApiEnvironment = 'Dev';

/// Where to find the company the Cypress suite provisioned.
///
/// Relative to the Front-End package root, which is the working directory
/// `flutter test` runs in.
const String kCredentialsPath = '../e2e/output/pos-credentials.json';

/// Which company in that file to sign in as.
///
/// `null` takes the newest entry — normally what you want, since the Cypress
/// run that just created a company writes it to the front of the list. Set an
/// explicit id to pin a test to one company.
const int? kCompanyId = null;

/// The device identity this test registers with, reused across runs.
///
/// 🚨 Pinned on purpose, and it is not cosmetic. Wiping the terminal clears
/// `device_id`, so `getOrCreateDeviceId()` would mint a brand-new
/// `POS-<uuid>` on every run — and the server enforces the seat cap at master
/// login (Pillar 4, `RegisterOrValidateDeviceAsync`). A company licensed for 3
/// terminals would therefore let this test pass exactly three times and then
/// fail the fourth with "This account is licensed for 3 terminal(s) and that
/// limit is reached", for a reason that has nothing to do with the code under
/// test.
///
/// Seeding a fixed id keeps the run a genuine first install — no token, no
/// registration, no onboarding — while re-registering the SAME terminal
/// instead of leaking a seat each time.
///
/// Set to `null` to let the app generate a fresh id, which is what a real new
/// terminal does. Only do that when you mean to consume a seat.
// Nullable on purpose: `null` is a meaningful setting here, not an oversight.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kDeviceId = 'POS-e2e-login-new-company';

// ───────────────────────────────────────────────────────────────────────────
// setup_catalog — the catalogue test that reuses an already-registered
// terminal. It never burns a seat, because it never re-registers the device.
// ───────────────────────────────────────────────────────────────────────────

/// The language the catalogue test switches the terminal to before it starts.
///
/// One of the codes that actually has an .arb file: 'en', 'fr' or 'ar'.
/// Switching first is not decoration — it pins every label the rest of the run
/// looks for, so the test does not depend on whatever language the company
/// happened to be left in.
const String kLanguageCode = 'en';

/// The tax the catalogue test creates, as a percentage.
const String kTaxRatePercent = '20';

/// How the two product groups are shaped: one root folder and one child of it,
/// so the parent/child relationship is actually exercised rather than assumed.
const String kParentGroupName = 'Beverages';
const String kChildGroupName = 'Hot Drinks';

/// Display rank given to each created group and product. Any integer.
const String kDisplayRank = '1';
