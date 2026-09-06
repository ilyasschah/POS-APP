/// <reference types="cypress" />

import { faker } from '@faker-js/faker';

/**
 * Provision a brand-new organization end to end, the way an operator does it.
 *
 * NOTHING HERE IS MOCKED. Every run drives the real form against the real API
 * and leaves a real company, a real Master-DB subscription tenant and a real
 * user behind in the dev database. That is the point: when this passes, the
 * rows are there to look at in SSMS.
 *
 * The generated POS login is written to e2e/output/pos-credentials.txt at the
 * end of the run, because the front-end app needs it to sign in.
 */

// A short, sortable tag stamped into every generated value, so a row in the
// database can be traced back to the run that made it.
const runTag = new Date().toISOString().slice(5, 16).replace(/[-:T]/g, '');

const slug = (s) =>
  s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, '');

const firstName = faker.person.firstName();
const lastName = faker.person.lastName();

const company = {
  name: faker.company.name() + ' [E2E ' + runTag + ']',
  email: 'billing.' + runTag + '@octopus-e2e.test',
  phone: faker.phone.number({ style: 'international' }),
  address: faker.location.streetAddress(),
  city: faker.location.city(),
  postalCode: faker.location.zipCode('#####'),
  taxNumber: 'TAX' + faker.string.numeric(9),
};

const user = {
  // 3-50 characters (AddUserCommandValidator). The tag keeps it unique across
  // runs; the slice keeps a long surname from pushing it over the cap.
  username: (slug(firstName) + '.' + slug(lastName)).slice(0, 30) + '.' + runTag,
  // Minimum 6 characters server-side. No braces: Cypress .type() reads {...}
  // as a special key sequence.
  password: 'Pos' + faker.string.alphanumeric({ length: 8, casing: 'mixed' }) + '!7',
  firstName,
  lastName,
  get email() {
    // 🚨 The POS front-end signs in on EMAIL, and UserRepository looks it up
    // with FirstOrDefaultAsync(u => u.Email == email) across EVERY company -
    // no company scoping. A duplicate email would hand the till the wrong
    // company's user, so this has to be unique database-wide.
    return this.username + '@octopus-e2e.test';
  },
};

const subscriptionDays = Cypress.expose('subscriptionDays');
const seatAllowance = Cypress.expose('seatAllowance');

// Filled in by the first test and read by the rest.
const provisioned = { companyId: null };

/** Tabler datagrid: <div><div class="datagrid-title">X</div><div class="datagrid-content">v</div></div> */
const datagridValue = (title) =>
  cy.contains('.datagrid-title', title).siblings('.datagrid-content');

describe('Admin portal - provision a new organization', () => {
  beforeEach(() => {
    cy.adminLogin();
  });

  it('creates the company from the Provision form', () => {
    cy.visit('/admin/companies/create');
    cy.contains('.page-title', 'Provision New Organization').should('be.visible');

    // ── Organization profile ────────────────────────────────────────────────
    cy.get('#Input_Name').type(company.name);
    cy.chooseCountry();
    cy.get('#Input_Email').type(company.email);
    cy.get('#Input_PhoneNumber').type(company.phone);
    cy.get('#Input_Address').type(company.address);
    cy.get('#Input_City').type(company.city);
    cy.get('#Input_PostalCode').type(company.postalCode);
    cy.get('#Input_TaxNumber').type(company.taxNumber);

    // ── Logo ────────────────────────────────────────────────────────────────
    cy.get('#Logo').selectFile(Cypress.expose('logoPath'));
    // The inline previewLogo() reader swaps the placeholder for the image. If
    // this never happens the file was not attached, and the upload assertions
    // further down would then fail for a reason that looks unrelated.
    cy.get('#logoPreviewInitial').should('not.be.visible');
    cy.get('#logoPreview')
      .should('have.attr', 'style')
      .and('match', /background-image:\s*url\(/);

    // ── Subscription and seats ──────────────────────────────────────────────
    cy.get('#Input_SubscriptionDays').select(String(subscriptionDays));
    cy.get('#Input_SeatAllowance').clear().type(String(seatAllowance));

    // ── Initial user ────────────────────────────────────────────────────────
    // The fields sit behind pointer-events:none until the switch is on, so the
    // toggle is not optional politeness - typing first would silently no-op.
    cy.get('#firstUserFields').should('have.css', 'pointer-events', 'none');
    cy.get('#createFirstUserToggle').check();
    cy.get('#firstUserFields').should('have.css', 'pointer-events', 'auto');

    cy.get('#Input_Username').type(user.username);
    cy.get('#Input_Password').type(user.password, { log: false });
    // 🚨 0 is Admin, 1 is Cashier (Domain/AccessLevels.cs). This form once
    // offered them the other way round and shipped, so every company's first
    // "Admin" was a cashier who could not open Management. Pinned by value.
    cy.get('#Input_AccessLevel').select('0');
    cy.get('#Input_FirstName').type(user.firstName);
    cy.get('#Input_LastName').type(user.lastName);
    cy.get('#Input_UserEmail').type(user.email);

    cy.contains('button[type=submit]', 'Create Organization').click();

    // ── The redirect proves the whole POST committed ────────────────────────
    cy.location('pathname', { timeout: 60000 })
      .should('match', /\/admin\/companies\/details\/\d+/i)
      .then((pathname) => {
        provisioned.companyId = Number(pathname.match(/(\d+)$/)[1]);
        expect(provisioned.companyId, 'new company id').to.be.greaterThan(0);
        cy.task('log', 'Provisioned company #' + provisioned.companyId + ': ' + company.name);
      });

    cy.get('.alert-success')
      .should('be.visible')
      .and('contain.text', "Company '" + company.name + "' created.");

    // The page reports a logo failure separately, so a green success banner is
    // not on its own proof that the logo landed.
    cy.get('body').then(($body) => {
      const warning = $body.find('.alert-warning:contains("logo")');
      if (warning.length > 0) {
        throw new Error(
          'The company was created but the logo did not save: ' + warning.text().trim());
      }
    });
  });

  it('saved the organization profile exactly as entered', () => {
    cy.visit('/admin/companies/details/' + provisioned.companyId);

    cy.get('.page-pretitle').should('contain.text', 'Organization #' + provisioned.companyId);
    cy.get('.page-title').should('contain.text', company.name);

    datagridValue('Email').should('contain.text', company.email);
    datagridValue('City').should('contain.text', company.city);
    datagridValue('Tax #').should('contain.text', company.taxNumber);

    // The phone is re-rendered verbatim; compare on digits so a display-only
    // space or dash does not fail a test about persistence.
    const digits = (s) => s.replace(/\D/g, '');
    datagridValue('Phone')
      .invoke('text')
      .then((text) => {
        expect(digits(text)).to.eq(digits(company.phone));
      });

    datagridValue('Country').should('not.contain.text', '—');
  });

  it('provisioned the Master-DB subscription tenant', () => {
    cy.visit('/admin/companies/details/' + provisioned.companyId);

    // 🚨 The real risk this covers: ProvisionTenantAsync runs OUTSIDE the
    // company transaction and its failure is caught and logged as a WARNING, so
    // a Master-DB outage produces a company that was created perfectly and can
    // never license a till. The portal is the only place that shows it.
    cy.contains('No control-plane tenant for this company yet').should('not.exist');

    datagridValue('Billing Status').should('not.contain.text', '—');

    datagridValue('Days Left')
      .invoke('text')
      .then((text) => {
        const days = Number(text.replace(/[^\d-]/g, ''));
        // Rounding across the UTC boundary can shave a day either way.
        expect(days, 'days left for a ' + subscriptionDays + '-day subscription')
          .to.be.within(subscriptionDays - 1, subscriptionDays + 1);
      });

    datagridValue('Expires')
      .invoke('text')
      .then((text) => {
        const iso = text.trim();
        expect(iso, 'expiry date').to.match(/^\d{4}-\d{2}-\d{2}$/);
        expect(new Date(iso).getTime(), 'expiry is in the future')
          .to.be.greaterThan(Date.now());
      });

    // "<registered> / <allowance>" - no till has enrolled yet, so 0 of N.
    datagridValue('Active Devices')
      .invoke('text')
      .then((text) => {
        expect(text.replace(/\s+/g, ' ').trim()).to.eq('0 / ' + seatAllowance);
      });
  });

  it('stored a logo the POS can actually print', () => {
    cy.visit('/admin/companies/details/' + provisioned.companyId);

    // The avatar only renders when CompanyLogoFile.ContentType() recognises the
    // stored bytes, so its presence already means a printable format survived.
    cy.get('.page-header .avatar')
      .should('have.attr', 'style')
      .and('include', 'handler=Logo');

    // Fetch the bytes back out of the database through the portal's own handler.
    cy.request('/admin/companies?handler=Logo&id=' + provisioned.companyId).then((res) => {
      expect(res.status).to.eq(200);
      expect(res.headers['content-type'], 'a format the receipt printer decodes')
        .to.match(/^image\/(png|jpeg)/);
      expect(res.headers['etag'], 'served with an ETag').to.exist;
    });
  });

  it('created the initial user as an Admin, not a cashier', () => {
    cy.visit('/admin/companies/details/' + provisioned.companyId);

    cy.contains('.card-header', 'Users')
      .closest('.card')
      .within(() => {
        cy.contains('tr', user.username).within(() => {
          cy.contains(user.email).should('exist');
          cy.contains(user.firstName).should('exist');
          // 🚨 The regression guard: a Cashier badge here means the access
          // level mapping has been inverted again.
          cy.get('.badge').should('have.text', 'Admin');
          cy.contains('.status', 'Active').should('exist');
        });
      });
  });

  it('lists the new company on the dashboard and the subscriptions page', () => {
    cy.visit('/admin/companies');
    cy.contains('tr', company.name).should('exist');

    cy.visit('/admin/subscriptions');
    cy.contains('tr', company.name)
      .should('exist')
      .within(() => {
        // The seat allowance the subscription is actually licensed for, read
        // back from the Master DB rather than from the form we just posted.
        cy.get('input[name="seats"]').should('have.value', String(seatAllowance));
      });
  });

  it('writes the POS front-end credentials to e2e/output/', () => {
    // Runs last so it only records a company every assertion above accepted.
    expect(provisioned.companyId, 'company id from the create step').to.be.a('number');

    cy.task('saveCredentials', {
      createdAtUtc: new Date().toISOString(),
      companyId: provisioned.companyId,
      companyName: company.name,
      username: user.username,
      userEmail: user.email,
      userPassword: user.password,
      firstName: user.firstName,
      lastName: user.lastName,
      accessLevel: 0,
      accessLevelName: 'Admin',
      companyEmail: company.email,
      companyPhone: company.phone,
      companyCity: company.city,
      companyTaxNumber: company.taxNumber,
      subscriptionDays,
      seatAllowance,
      logoName: Cypress.expose('logoName'),
      adminPortalUrl:
        Cypress.config('baseUrl') + '/admin/companies/details/' + provisioned.companyId,
    }).then((result) => {
      cy.task(
        'log',
        '\nPOS login for company #' + provisioned.companyId +
          ' written to:\n  ' + result.txtPath +
          '\n  Email    : ' + user.email +
          '\n  Password : ' + user.password + '\n'
      );
    });
  });
});
