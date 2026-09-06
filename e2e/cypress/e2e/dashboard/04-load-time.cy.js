/// <reference types="cypress" />

/**
 * How long the dashboard takes to paint its first frame.
 *
 * 🚨 Read the number before believing it is a product problem. What this
 * measures depends entirely on HOW the app is being served:
 *
 *   flutter run -d web-server   ~10-11s cold, ~5s warm
 *       Debug/DDC. `main.dart.js` is a 7.7 KB LOADER that then pulls hundreds
 *       of separate unminified module files over separate requests. The round
 *       trips are the cost, not the app.
 *
 *   a static server over `flutter build web --release`
 *       One 3.65 MB dart2js bundle, tree-shaken and minified. This is what
 *       production actually serves - IIS from C:\inetpub\wwwroot\dashboard,
 *       deployed from the `prod` branch - so the debug figure above says
 *       nothing about what a customer experiences.
 *
 * The ceiling here is deliberately loose. It is not a performance budget; it
 * separates "loads" from "hangs", and a tight bound would flake on a cold
 * debug server for no useful reason.
 */
const CEILING_MS = 60000;

describe('Owner Dashboard - load time', () => {
  it('paints its first frame and reports how long that took', () => {
    cy.dashboardVisit();

    cy.window().then((win) => {
      const ms = win.__firstFrameAt - win.__visitStartedAt;

      cy.task('log',
        '\n  Dashboard time-to-first-frame: ' + ms + ' ms' +
        '\n  (~10s means a DEBUG `flutter run` server; a release build is far quicker)\n');

      expect(ms, 'time to first frame (ms)').to.be.lessThan(CEILING_MS);
    });
  });
});
