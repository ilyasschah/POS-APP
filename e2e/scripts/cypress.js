#!/usr/bin/env node
/**
 * Launches the Cypress CLI with a clean environment.
 *
 * 🚨 ELECTRON_RUN_AS_NODE. VS Code's extension host exports this, and any
 * terminal, task or agent spawned from inside VS Code inherits it. Cypress.exe
 * IS an Electron binary, so with that variable set it starts as plain Node,
 * does not understand its own arguments, and the install verification dies with
 *
 *     Cypress.exe: bad option: --smoke-test
 *     Cypress failed to start. This may be due to a missing library or
 *     dependency.
 *
 * which sends you looking for a missing system library that is not missing.
 * Deleting the variable for the child process is the whole fix. Running from a
 * standalone PowerShell or cmd window never hits it.
 *
 * Everything after `node scripts/cypress.js` is passed straight through, so
 * this is a drop-in for `npx cypress`:
 *
 *     node scripts/cypress.js open
 *     node scripts/cypress.js run --spec cypress/e2e/admin-portal/01-admin-login.cy.js
 */
const path = require('path');
const { spawn } = require('child_process');

const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;

// Resolved through the module system rather than a hardcoded node_modules path,
// so a hoisted install still works. It goes via package.json because Cypress 16
// ships an "exports" map that does NOT expose ./bin/cypress — requiring that
// path directly fails with ERR_PACKAGE_PATH_NOT_EXPORTED. The "bin" field is
// the package's own declaration of where its CLI lives, so it stays correct if
// they move it.
const pkgJson = require.resolve('cypress/package.json');
const pkg = require(pkgJson);
const cli = path.join(path.dirname(pkgJson), pkg.bin.cypress);

const child = spawn(process.execPath, [cli, ...process.argv.slice(2)], {
  stdio: 'inherit',
  env,
});

child.on('exit', (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exit(code === null ? 1 : code);
});

child.on('error', (err) => {
  console.error('Could not start Cypress:', err.message);
  process.exit(1);
});
