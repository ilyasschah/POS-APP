/**
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │  TEMPLATE — committed to git. Copy to `test-config.js` and fill it in.   │
 * │      cp config/test-config.example.js config/test-config.js             │
 * └──────────────────────────────────────────────────────────────────────────┘
 *
 * `test-config.js` is GIT-IGNORED because it holds a real admin password and
 * THIS REPOSITORY IS PUBLIC. Never move these values into a committed file.
 *
 * Everything here is an INPUT you set before running Cypress. The credentials
 * the tests GENERATE (the POS user's email / password) are written out to
 * `e2e/output/pos-credentials.json` — the tests never write back to this file,
 * so your edits are safe.
 */
module.exports = {
  // ── Where the API + admin portal are running ────────────────────────────
  // From Back-End/Web-POS.Api/Properties/launchSettings.json ("http" profile).
  baseUrl: 'http://100.114.12.38:5002',

  // The Octopus Owner Dashboard (Flutter web). Used by the dashboard specs to
  // verify a provisioned company can actually sign in and see its own data.
  dashboardBaseUrl: 'http://100.114.12.38:8081',

  // ── Admin portal sign-in (the account YOU use at /admin/login) ──────────
  // The seeded default is Admin / Admin@123 — see Admin/AdminUserSeeder.cs.
  // If you have changed it (the portal nags you to), put the real one here.
  adminUsername: 'FILL_ME',
  adminPassword: 'FILL_ME',

  // ── Subscription the test provisions for the new company ────────────────
  // Must be one of the options the Create form offers: 14, 30, 90, 180, 365.
  subscriptionDays: 30,

  // Seat allowance = "Seat Allowance (Terminals)" on the Create form: the
  // maximum number of devices allowed to sync. This is your device number.
  seatAllowance: 3,

  // ── Company logo ────────────────────────────────────────────────────────
  // Absolute path, or relative to the `e2e/` folder.
  // 🚨 PNG or JPEG ONLY, max 2 MB. A WebP/SVG uploads and previews fine and
  // then prints as NOTHING on every receipt — see Admin/CompanyLogoFile.cs.
  // Leave '' to use the bundled brand icon at
  // Back-End/Web-POS.Api/wwwroot/img/icon.png.
  logoPath: '',

  // ── Country ─────────────────────────────────────────────────────────────
  // The Create form shows a dropdown when the DB has countries; the test picks
  // the first real one. This ID is the fallback used only when that table is
  // empty and the form degrades to a plain number input.
  fallbackCountryId: 1,
};
