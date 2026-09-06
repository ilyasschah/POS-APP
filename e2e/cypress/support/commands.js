/// <reference types="cypress" />

/**
 * Sign in to the admin portal.
 *
 * Wrapped in cy.session so the cookie is established once and replayed for
 * every later test. `cacheAcrossSpecs` keeps it alive between spec files, which
 * matters because AdminUserService deliberately equalises the response time of
 * a failed login — sign-in is not a fast operation and there is no reason to
 * pay for it once per test.
 */
Cypress.Commands.add('adminLogin', () => {
  const username = Cypress.expose('adminUsername');

  cy.session(
    ['admin-portal', username],
    () => {
      cy.visit('/admin/login');

      // asp-for="Input.Username" renders id="Input_Username".
      cy.get('#Input_Username').should('be.visible').type(username);

      // The password lives in `env` rather than `expose`, so it is read through
      // cy.env - a command, not a synchronous getter. Cypress 16 draws that
      // line deliberately: secrets are not readable outside the command queue.
      cy.env(['adminPassword']).then(({ adminPassword }) => {
        cy.get('#Input_Password').type(adminPassword, { log: false });
      });

      cy.contains('button[type=submit]', 'Sign in').click();

      // A failed sign-in re-renders the form with an alert instead of
      // redirecting. Name that explicitly: otherwise every downstream test
      // fails on a missing element and never says the password was wrong.
      cy.location('pathname', { timeout: 30000 }).then((pathname) => {
        if (/\/admin\/login/i.test(pathname)) {
          cy.get('.alert-danger').then(($alert) => {
            throw new Error(
              'Admin portal sign-in failed for user "' + username + '".\n' +
              'The portal said: "' + $alert.text().trim() + '"\n' +
              'Fix adminUsername / adminPassword in e2e/config/test-config.js.'
            );
          });
        }
      });

      cy.location('pathname', { timeout: 30000 })
        .should('match', /\/admin\/companies/i);
    },
    {
      // An unauthenticated request is answered with a 302 to the login page,
      // so following redirects here would turn "signed out" into a green 200.
      validate() {
        cy.request({
          url: '/admin/companies',
          followRedirect: false,
          failOnStatusCode: false,
        })
          .its('status')
          .should('eq', 200);
      },
      cacheAcrossSpecs: true,
    }
  );
});

/**
 * The Country control on the Create form has two shapes: a <select> when the
 * database holds countries, and a bare number input when it does not (see
 * Create.cshtml). Handle both, and report which one was used — a run that
 * silently fell back to the number input is a run against a DB with no
 * countries seeded, which is worth knowing.
 */
Cypress.Commands.add('chooseCountry', () => {
  cy.get('body').then(($body) => {
    const select = $body.find('select#Input_CountryId');

    if (select.length > 0) {
      // Skip the "-- Select Country --" placeholder, whose value is "".
      cy.get('select#Input_CountryId option')
        .not('[value=""]')
        .should('have.length.greaterThan', 0)
        .first()
        .then(($opt) => {
          const id = $opt.val();
          const label = $opt.text().trim();
          cy.get('select#Input_CountryId').select(String(id));
          cy.wrap({ id: Number(id), label, source: 'dropdown' }).as('country');
        });
    } else {
      const id = Cypress.expose('fallbackCountryId');
      cy.task('log',
        'No Country dropdown on the form - the Country table is empty. ' +
        'Falling back to fallbackCountryId=' + id + ' from test-config.js.');
      cy.get('input#Input_CountryId').clear().type(String(id));
      cy.wrap({ id: Number(id), label: null, source: 'fallback' }).as('country');
    }
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Octopus Owner Dashboard (Flutter web, CanvasKit)
// ─────────────────────────────────────────────────────────────────────────────
//
// 🚨 CanvasKit paints the entire UI into a <canvas>. There is no DOM for a
// TextField or a button, so nothing here can be selected the ordinary way.
// Flutter does build a real DOM accessibility tree, but only ON DEMAND: it
// renders a 1x1 <flt-semantics-placeholder> and waits for someone to activate
// it. Clicking that is what turns the app into something a browser driver can
// see, and it is why every dashboard test starts with cy.dashboardVisit().

/**
 * Open the dashboard on a genuinely clean browser and make it inspectable.
 *
 * 🚨 "Clear the cookies" is the wrong instinct here and would do nothing: the
 * session is not in a cookie. shared_preferences on web is backed by
 * localStorage, under keys Flutter prefixes with "flutter." —
 * flutter.apiToken, flutter.companyId, flutter.lastEmail, flutter.apiBaseUrl.
 * That is what carries the previous user into the next run, so the whole store
 * is cleared before the app boots. Cookies are cleared too, for the API side.
 */
Cypress.Commands.add('dashboardVisit', () => {
  cy.clearCookies();

  cy.visit(Cypress.expose('dashboardBaseUrl'), {
    timeout: 180000,
    onBeforeLoad(win) {
      // BEFORE the app boots, not after: AuthController.build() reads these
      // during the first frame, so clearing afterwards would still let the
      // previous session render once.
      try {
        win.localStorage.clear();
        win.sessionStorage.clear();
      } catch (e) {
        /* a browser with site data blocked - nothing to clear */
      }

      // index.html removes #app-loading 300ms AFTER this event, so the event is
      // the precise ready signal. Polling for the splash to disappear races
      // with that timer.
      win.__visitStartedAt = Date.now();
      win.__firstFrameAt = 0;
      win.addEventListener('flutter-first-frame', () => {
        win.__firstFrameAt = Date.now();
      });
    },
  });

  cy.window({ timeout: 180000 })
    .should((win) => {
      expect(win.__firstFrameAt, 'flutter-first-frame fired').to.be.greaterThan(0);
    })
    .then((win) => {
      const ms = win.__firstFrameAt - win.__visitStartedAt;
      cy.task('log', 'Dashboard first frame after ' + ms + 'ms');
    });

  cy.get('flt-semantics-placeholder', { timeout: 60000 }).click({ force: true });
  cy.get('flt-semantics', { timeout: 60000 }).should('exist');
});

/**
 * The login form's three TextFields, in DOM order.
 *
 * 🚨 Addressed by INDEX, not by aria-label, and that is deliberate. Flutter
 * labels an EMPTY field with aria-label="Email", then DROPS that attribute the
 * moment the field holds a value — the semantic label becomes the content. So
 * `input[aria-label="Email"]` finds the field on the first attempt and finds
 * NOTHING on a retry, which is how a retry meant to fix dropped keystrokes
 * turned into "Expected to find element: input[aria-label=Email]".
 *
 * The three <input> nodes themselves are stable: same elements, same order,
 * never replaced across focus or typing. Verified by probing the live app.
 */
const FLUTTER_LOGIN_FIELDS = { 'API Base URL': 0, Email: 1, Password: 2 };

/** Yields one login field, preferring its label while it still has one. */
function flutterField(label) {
  return cy.get('input', { timeout: 30000 }).then(($inputs) => {
    const labelled = $inputs.filter((i, el) => el.getAttribute('aria-label') === label);
    if (labelled.length > 0) return cy.wrap(labelled.first(), { log: false });

    const index = FLUTTER_LOGIN_FIELDS[label];
    if (index === undefined) {
      throw new Error(
        'Unknown Flutter field "' + label + '". Known: ' +
        Object.keys(FLUTTER_LOGIN_FIELDS).join(', '));
    }
    if ($inputs.length <= index) {
      throw new Error(
        'Expected at least ' + (index + 1) + ' inputs on the login form, found ' +
        $inputs.length + '. The form layout changed - update FLUTTER_LOGIN_FIELDS.');
    }
    return cy.wrap($inputs.eq(index), { log: false });
  });
}

const FLUTTER_TYPE_ATTEMPTS = 3;

/**
 * Types into whatever is currently focused, then verifies and retries.
 *
 * 🚨 Flutter attaches its text-editing connection asynchronously after a field
 * takes focus, and anything sent before that lands nowhere. It shows up as the
 * FIRST characters going missing — "jarret.toy...@octopus-e2e.test" arriving as
 * "opus-e2e.test" — and because it is a race it passes on a cold app and fails
 * on a warm one. Verifying the value and retyping is what makes it dependable;
 * without it the suite signs in with a truncated email and blames the password.
 */
function attemptType(label, text, secret, typeOptions, attempt) {
  cy.focused()
    .clear({ force: true })
    .type(text, { force: true, delay: 40, log: !secret, ...typeOptions });

  cy.focused().then(($el) => {
    if ($el.val() === text) return;

    if (attempt >= FLUTTER_TYPE_ATTEMPTS) {
      throw new Error(
        'Flutter field "' + label + '" kept dropping keystrokes after ' +
        FLUTTER_TYPE_ATTEMPTS + ' attempts: expected ' + text.length +
        ' characters, got ' + String($el.val()).length + '.');
    }

    cy.task('log',
      'Flutter dropped keystrokes in "' + label + '" (attempt ' + attempt + '): got ' +
      String($el.val()).length + ' of ' + text.length + ' characters. Retrying.');

    attemptType(label, text, secret, typeOptions, attempt + 1);
  });
}

/**
 * Type into a Flutter TextField by the label its semantics tree gives it.
 *
 * `force` is not laziness: Flutter stacks the editing <input> under the canvas
 * with a transform, so Cypress's visibility and covered-element checks reject
 * the very element that receives the keystrokes.
 */
Cypress.Commands.add('flutterType', (label, text, options = {}) => {
  const { secret = false, ...typeOptions } = options;

  flutterField(label).click({ force: true });

  // Give the editing connection time to attach before the first keystroke.
  cy.wait(600);
  cy.focused().should('match', 'input');

  attemptType(label, text, secret, typeOptions, 1);

  // Final gate. A secret is compared by LENGTH so its value never reaches the
  // command log or a failure screenshot.
  cy.focused().should(($el) => {
    if (secret) {
      expect($el.val(), label + ' length').to.have.length(text.length);
    } else {
      expect($el.val(), label).to.eq(text);
    }
  });
});

/** Tap a Flutter button by the label the semantics tree gives it. */
Cypress.Commands.add('flutterTap', (label) => {
  cy.contains('flt-semantics[role=button]', label, { timeout: 30000 }).click();
});
