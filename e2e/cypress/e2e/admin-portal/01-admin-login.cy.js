/// <reference types="cypress" />

/**
 * Admin portal authentication.
 *
 * This spec writes nothing. It exists because every other spec depends on the
 * cookie scheme being wired correctly, and that wiring is easy to break in a
 * way that produces no error at all: the API's DEFAULT auth scheme is
 * JwtBearer, so a policy that forgets to name AdminPortalCookie authenticates
 * the browser against the bearer handler, never sees the cookie, and
 * challenges forever (see Admin/AdminPortalAuth.cs).
 */
describe('Admin portal - authentication', () => {
  it('sends an anonymous visitor to the login form', () => {
    cy.clearCookies();

    // followRedirect:false so the 302 itself is the assertion. Following it
    // would land on the login page with a green 200 and prove nothing.
    cy.request({
      url: '/admin/companies',
      followRedirect: false,
      failOnStatusCode: false,
    }).then((res) => {
      expect(res.status, 'protected page redirects when signed out').to.eq(302);
      expect(res.redirectedToUrl, 'redirect target').to.match(/\/admin\/login/i);
    });
  });

  it('redirects /admin and / to the companies dashboard', () => {
    // No Razor page lives at /admin - Program.cs maps both of these by hand,
    // and without them the request matches no endpoint at all.
    cy.request({ url: '/admin', followRedirect: false, failOnStatusCode: false })
      .then((res) => {
        expect(res.status).to.be.oneOf([301, 302]);
        expect(res.redirectedToUrl).to.match(/\/admin\/companies/i);
      });

    cy.request({ url: '/', followRedirect: false, failOnStatusCode: false })
      .then((res) => {
        expect(res.status).to.be.oneOf([301, 302]);
        expect(res.redirectedToUrl).to.match(/\/admin\/companies/i);
      });
  });

  it('rejects a wrong password without revealing whether the user exists', () => {
    cy.clearCookies();
    cy.visit('/admin/login');

    cy.get('#Input_Username').type(Cypress.expose('adminUsername'));
    cy.get('#Input_Password').type('definitely-not-the-password-' + Date.now(), { log: false });
    cy.contains('button[type=submit]', 'Sign in').click();

    cy.location('pathname').should('match', /\/admin\/login/i);

    // One message for every failure. Naming the reason would turn the form into
    // a username oracle, so this exact wording is the security behaviour.
    cy.get('.alert-danger')
      .should('be.visible')
      .and('contain.text', 'Incorrect username or password.');
  });

  it('signs in with the configured credentials and lands on the dashboard', () => {
    cy.adminLogin();
    cy.visit('/admin/companies');

    cy.location('pathname').should('match', /\/admin\/companies/i);
    cy.get('.navbar').should('contain.text', 'POS Admin');

    // Signed-in chrome: these only render for an authenticated principal.
    cy.contains('a', 'New Company').should('be.visible');
    cy.contains('button', 'Sign out').should('exist');
  });
});
