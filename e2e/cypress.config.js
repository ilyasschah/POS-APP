const { defineConfig } = require('cypress');
const fs = require('fs');
const path = require('path');

// ── The operator's fill-in file ──────────────────────────────────────────────
// Not committed (it holds a real admin password, and this repo is public), so a
// fresh clone lands here with a missing file rather than a confusing failure.
const CONFIG_PATH = path.join(__dirname, 'config', 'test-config.js');
const EXAMPLE_PATH = path.join(__dirname, 'config', 'test-config.example.js');

if (!fs.existsSync(CONFIG_PATH)) {
  throw new Error(
    '\n\nMissing ' + CONFIG_PATH + '\n' +
    'Copy the template and fill it in:\n' +
    '    cp ' + EXAMPLE_PATH + ' ' + CONFIG_PATH + '\n'
  );
}

const cfg = require(CONFIG_PATH);

// ── Validation ───────────────────────────────────────────────────────────────
// Every one of these is checked HERE, in Node, before a browser is launched.
// The alternative is a test that opens Chrome, types "FILL_ME" into the login
// form and reports "Incorrect username or password" — which sends you off to
// reset an admin password that was never wrong.
const problems = [];

const required = (key) => {
  const v = cfg[key];
  if (typeof v !== 'string' || v.trim() === '' || v.trim() === 'FILL_ME') {
    problems.push('  - ' + key + ' is still unset. Edit config/test-config.js.');
  }
};

required('adminUsername');
required('adminPassword');

if (!cfg.baseUrl || !/^https?:\/\//.test(cfg.baseUrl)) {
  problems.push('  - baseUrl must be a full http(s) URL, e.g. http://100.114.12.38:5002');
}

if (!cfg.dashboardBaseUrl || !/^https?:\/\//.test(cfg.dashboardBaseUrl)) {
  problems.push(
    '  - dashboardBaseUrl must be a full http(s) URL, e.g. http://100.114.12.38:8081');
}

// The Create form renders these as <option> values, so anything else silently
// selects nothing and the company gets the server-side default instead.
const ALLOWED_DAYS = [14, 30, 90, 180, 365];
if (!ALLOWED_DAYS.includes(Number(cfg.subscriptionDays))) {
  problems.push(
    '  - subscriptionDays must be one of ' + ALLOWED_DAYS.join(', ') +
    ' (the Billing Period dropdown offers no other value). Got: ' + cfg.subscriptionDays
  );
}

const seats = Number(cfg.seatAllowance);
if (!Number.isInteger(seats) || seats < 1) {
  problems.push('  - seatAllowance must be a whole number >= 1. Got: ' + cfg.seatAllowance);
}

// ── Logo ─────────────────────────────────────────────────────────────────────
// Resolved and format-checked up front. CompanyLogoFile.cs refuses anything
// that is not PNG/JPEG *by magic bytes* — a renamed .webp announces itself as a
// PNG and would otherwise reach the server and be rejected mid-test.
const DEFAULT_LOGO = path.resolve(
  __dirname, '..', 'Back-End', 'Web-POS.Api', 'wwwroot', 'img', 'icon.png');

const logoPath = cfg.logoPath && String(cfg.logoPath).trim() !== ''
  ? path.resolve(__dirname, String(cfg.logoPath).trim())
  : DEFAULT_LOGO;

if (!fs.existsSync(logoPath)) {
  problems.push('  - logoPath does not exist: ' + logoPath);
} else {
  const MAX_BYTES = 2 * 1024 * 1024; // mirrors CompanyLogoFile.MaxBytes
  const size = fs.statSync(logoPath).size;
  if (size > MAX_BYTES) {
    problems.push(
      '  - logoPath is ' + (size / 1024 / 1024).toFixed(2) + ' MB - the portal ' +
      'refuses anything over 2 MB: ' + logoPath
    );
  }

  const head = Buffer.alloc(8);
  const fd = fs.openSync(logoPath, 'r');
  fs.readSync(fd, head, 0, 8, 0);
  fs.closeSync(fd);

  const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const JPEG = Buffer.from([0xff, 0xd8, 0xff]);
  const isPng = head.subarray(0, 8).equals(PNG);
  const isJpeg = head.subarray(0, 3).equals(JPEG);

  if (!isPng && !isJpeg) {
    problems.push(
      '  - logoPath is not a PNG or JPEG (checked by magic bytes, not by the\n' +
      '    extension). The POS prints receipts through a decoder that reads\n' +
      '    those two formats and nothing else, so anything else prints blank:\n' +
      '    ' + logoPath
    );
  }
}

if (problems.length > 0) {
  throw new Error(
    '\n\nE2E configuration is incomplete - nothing was run.\n\n' +
    problems.join('\n') +
    '\n\nFile: ' + CONFIG_PATH + '\n'
  );
}

const OUTPUT_DIR = path.join(__dirname, 'output');

module.exports = defineConfig({
  projectId: 'qb829q',
  e2e: {
    baseUrl: String(cfg.baseUrl).replace(/\/+$/, ''),
    specPattern: 'cypress/e2e/**/*.cy.js',
    supportFile: 'cypress/support/e2e.js',

    // These tests provision REAL companies in the dev database. Retrying a
    // half-finished create would leave a second orphan company behind every
    // time, so a failure stays a failure.
    retries: { runMode: 0, openMode: 0 },

    video: false,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    // The create POST writes the company, seeds ~150 rows, stores the logo and
    // provisions the Master-DB tenant before it redirects. That is a slow round
    // trip on a cold API.
    pageLoadTimeout: 60000,
    responseTimeout: 60000,
    viewportWidth: 1440,
    viewportHeight: 900,

    // ⚠️ Cypress 16 split what used to be one bag of variables in two, and
    // removed Cypress.env() entirely:
    //   env    -> SENSITIVE. Read asynchronously with cy.env(['key']).
    //   expose -> everything else. Read synchronously with Cypress.expose('key').
    // The admin password is the only real secret here, so it is the only thing
    // in env - keeping the rest in expose means specs can read it at module
    // scope, where a command like cy.env() cannot run.
    env: {
      adminPassword: cfg.adminPassword,
    },

    expose: {
      adminUsername: cfg.adminUsername,
      dashboardBaseUrl: String(cfg.dashboardBaseUrl).replace(/\/+$/, ''),
      subscriptionDays: Number(cfg.subscriptionDays),
      seatAllowance: seats,
      logoPath: logoPath,
      logoName: path.basename(logoPath),
      fallbackCountryId: Number(cfg.fallbackCountryId) || 1,
    },

    setupNodeEvents(on) {
      on('task', {
        /**
         * Writes the credentials the run generated. This is the handoff to the
         * POS front-end: that app signs in with an EMAIL, not the username, so
         * the email is the field that matters at the till.
         */
        saveCredentials(payload) {
          fs.mkdirSync(OUTPUT_DIR, { recursive: true });

          const jsonPath = path.join(OUTPUT_DIR, 'pos-credentials.json');
          const txtPath = path.join(OUTPUT_DIR, 'pos-credentials.txt');

          // Appended, not overwritten: each run provisions a real company, and
          // losing a previous run's password would orphan that company.
          let history = [];
          if (fs.existsSync(jsonPath)) {
            try {
              history = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
            } catch (e) {
              history = [];
            }
            if (!Array.isArray(history)) history = [];
          }
          history.unshift(payload);
          fs.writeFileSync(jsonPath, JSON.stringify(history, null, 2), 'utf8');

          const c = history[0];
          const lines = [
            '===========================================================',
            ' POS front-end login for the company the last run created',
            '===========================================================',
            ' Created (UTC) : ' + c.createdAtUtc,
            ' Company       : ' + c.companyName,
            ' Company ID    : ' + c.companyId,
            '',
            ' -- Sign in to the POS app with these --',
            ' Email         : ' + c.userEmail,
            ' Password      : ' + c.userPassword,
            '',
            ' The POS app authenticates on EMAIL, not username.',
            ' (Portal-side username, shown in the admin UI: ' + c.username + ')',
            '',
            ' Subscription  : ' + c.subscriptionDays + ' days',
            ' Seats/devices : ' + c.seatAllowance,
            ' Logo uploaded : ' + c.logoName,
            '',
            ' Verify in SQL Server:',
            '   SELECT * FROM [web-pos].dbo.Company WHERE Id = ' + c.companyId + ';',
            '   SELECT * FROM [web-pos].dbo.[User]  WHERE CompanyId = ' + c.companyId + ';',
            '   SELECT * FROM [web-pos-master].dbo.Tenant WHERE CompanyId = ' + c.companyId + ';',
            '===========================================================',
            '',
            ' Earlier runs are kept in pos-credentials.json (newest first).',
            '',
          ];
          fs.writeFileSync(txtPath, lines.join('\n'), 'utf8');

          return { jsonPath: jsonPath, txtPath: txtPath, runs: history.length };
        },

        /**
         * Hands a spec the credentials a previous provisioning run generated.
         * `which: "latest"` (default) is the newest company; a number selects a
         * specific companyId, so a dashboard test can be pointed at one.
         *
         * Read here in Node rather than imported by the spec: the file is
         * written DURING a run, so bundling it into the spec would freeze
         * whatever existed when the bundle was built.
         */
        readCredentials(which) {
          const jsonPath = path.join(OUTPUT_DIR, 'pos-credentials.json');

          if (!fs.existsSync(jsonPath)) {
            throw new Error(
              'No credentials yet at ' + jsonPath + '.\n' +
              'Run the provisioning spec first:  npm run test:company'
            );
          }

          const history = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
          if (!Array.isArray(history) || history.length === 0) {
            throw new Error('No companies recorded in ' + jsonPath + '.');
          }

          if (which && which !== 'latest') {
            const found = history.find((c) => c.companyId === Number(which));
            if (!found) {
              throw new Error(
                'No company ' + which + ' in ' + jsonPath + '. Recorded: ' +
                history.map((c) => c.companyId).join(', ')
              );
            }
            return found;
          }

          return history[0];
        },

        log(message) {
          console.log(message);
          return null;
        },
      });
    },
  },
});
