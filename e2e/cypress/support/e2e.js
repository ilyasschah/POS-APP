/// <reference types="cypress" />

import './commands';

/**
 * Tabler's bundle and the theme script run on every portal page. A stray
 * ResizeObserver notification there is a browser quirk, not a product failure,
 * and it would otherwise fail an unrelated assertion.
 *
 * Deliberately narrow: everything else still fails the test, including real
 * page errors thrown by the portal's own scripts.
 */
Cypress.on('uncaught:exception', (err) => {
  if (/ResizeObserver loop/.test(err.message)) return false;
  return true;
});
