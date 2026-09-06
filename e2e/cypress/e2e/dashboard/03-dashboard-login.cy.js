/// <reference types="cypress" />

/**
 * Octopus Owner Dashboard (Flutter web) — signing in as a company the admin
 * portal provisioned earlier in this suite.
 *
 * This is the other half of the loop: 02-provision-company.cy.js creates a
 * company through the portal and writes its login to output/, and this spec
 * proves that login actually works in the product and that the dashboard comes
 * up scoped to THAT company.
 *
 * Run `npm run test:company` at least once first, so there is a company to
 * sign in as.
 */
describe('Owner Dashboard - sign in as a provisioned company', () => {
  let creds;

  before(() => {
    // 'latest' = the newest company in output/pos-credentials.json.
    cy.task('readCredentials', 'latest').then((c) => {
      creds = c;
      cy.task('log', 'Signing in as ' + c.userEmail + ' (company ' + c.companyId + ')');
    });
  });

  it('starts signed out, with no trace of the previous user', () => {
    cy.dashboardVisit();

    // 🚨 The complaint this pins down: the app "keeps holding the old login
    // user". It is not a cookie — AuthController.build() restores the session
    // from shared_preferences, which on web is localStorage under keys Flutter
    // prefixes with "flutter.". dashboardVisit() clears that store before the
    // app boots; this asserts the clearing actually took.
    cy.window().then((win) => {
      const leftovers = Object.keys(win.localStorage)
        .filter((k) => k.startsWith('flutter.'));
      expect(leftovers, 'session keys surviving into a fresh run').to.deep.eq([]);
    });

    // The login screen, not a restored dashboard.
    cy.contains('flt-semantics[role=button]', 'Sign In').should('exist');
    cy.contains('flt-semantics', 'Octopus Owner').should('exist');

    // lastEmail is what pre-fills this field, so an empty box is the visible
    // proof that no previous operator's account is being offered.
    cy.get('input[aria-label="Email"]').should('have.value', '');
  });

  it('signs in against the Dev environment', () => {
    cy.dashboardVisit();

    // Selecting Dev also rewrites the API Base URL field
    // (_selectEnvironment -> _urlController.text), so the URL is never typed.
    // It matters: the app's compiled-in default is PRODUCTION, so a test that
    // skipped this would sign in against the live system.
    cy.flutterTap('Dev');

    cy.flutterType('Email', creds.userEmail);
    cy.flutterType('Password', creds.userPassword, { secret: true });

    cy.flutterTap('Sign In');

    // The nav rail only exists once authenticated.
    cy.contains('flt-semantics[role=button]', 'Dashboard', { timeout: 60000 })
      .should('exist');
    cy.contains('flt-semantics[role=button]', 'POS Sessions').should('exist');
    cy.contains('flt-semantics[role=button]', 'Products & Prices').should('exist');
    cy.contains('flt-semantics[role=button]', 'Stock').should('exist');
    cy.contains('flt-semantics[role=button]', 'Documents').should('exist');
    cy.contains('flt-semantics[role=button]', 'User Management').should('exist');
    cy.contains('flt-semantics[role=button]', 'Settings').should('exist');
  });

  it('scopes the dashboard to the company that signed in', () => {
    cy.dashboardVisit();
    cy.flutterTap('Dev');
    cy.flutterType('Email', creds.userEmail);
    cy.flutterType('Password', creds.userPassword, { secret: true });
    cy.flutterTap('Sign In');

    cy.contains('flt-semantics[role=button]', 'Dashboard', { timeout: 60000 })
      .should('exist');

    cy.window().then((win) => {
      // 🚨 This is the regression guard for a bug the code documents: the
      // company id used to be the compile-time constant 25, applied to every
      // request no matter who signed in, so the dashboard reported company 25's
      // figures to everyone and a freshly created company looked like it had no
      // access. The id must come from the login response.
      expect(
        Number(win.localStorage.getItem('flutter.companyId')),
        'company the session is scoped to'
      ).to.eq(creds.companyId);

      // Both halves or neither — a token without a company is a stale key, not
      // a session (AuthState.isAuthenticated).
      expect(win.localStorage.getItem('flutter.apiToken'), 'session token')
        .to.be.a('string').and.not.be.empty;

      // Proof it really talked to Dev and not the compiled-in Production default.
      expect(win.localStorage.getItem('flutter.apiBaseUrl'), 'API the session used')
        .to.contain('100.114.12.38:5002');
    });
  });

  it('reports a brand-new company as having no sales yet', () => {
    cy.dashboardVisit();
    cy.flutterTap('Dev');
    cy.flutterType('Email', creds.userEmail);
    cy.flutterType('Password', creds.userPassword, { secret: true });
    cy.flutterTap('Sign In');

    cy.contains('flt-semantics[role=button]', 'Dashboard', { timeout: 60000 })
      .should('exist');

    // The company was provisioned minutes ago and has never taken an order, so
    // this is the honest answer. It also proves the dashboard queried the API
    // for THIS company rather than rendering someone else's figures.
    cy.contains('flt-semantics', 'Total Sales', { timeout: 60000 }).should('exist');
    cy.contains('flt-semantics', '0.00 DH').should('exist');
    cy.contains('flt-semantics', 'No sales activity').should('exist');
  });

  it('rejects a wrong password', () => {
    cy.dashboardVisit();
    cy.flutterTap('Dev');
    cy.flutterType('Email', creds.userEmail);
    cy.flutterType('Password', 'not-the-password-' + Date.now(), { secret: true });
    cy.flutterTap('Sign In');

    // Still on the login screen, and no session was written.
    cy.contains('flt-semantics[role=button]', 'Sign In').should('exist');
    cy.window().then((win) => {
      expect(win.localStorage.getItem('flutter.apiToken'), 'token after a failed sign-in')
        .to.be.null;
    });
  });
});
