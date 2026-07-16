-- Drops the ApplicationProperty rows for the six settings removed on 2026-07-16
-- (the §2.3 "POS layout / New sale / Order name" removal).
--
-- Every one of these keys is gone from the code: no SettingKeys entry, no
-- kSettingDefaults default, no Settings control, no searchable-settings entry,
-- no backend seeder line, and no reader anywhere in Front-End, Back-End or
-- kitchen_display (verified by grep across the repo). These rows are orphans:
-- AppSettingsNotifier merges DB rows over kSettingDefaults, so they load into
-- the settings map on every launch and are read by nothing.
--
-- Safe to re-run: the DELETE is a no-op once the rows are gone.
--
-- ── RUN ORDER MATTERS ───────────────────────────────────────────────────────
-- Run this on SQL SERVER FIRST. The local Drift DB mirrors the server, so
-- deleting locally on its own just gets the rows pulled back on the next sync.
-- Then delete the local rows (see the sqlite block at the bottom), or simply
-- let them sit — nothing reads them either way.
--
-- Rows as they stood on 2026-07-16, for recovery if this is ever regretted:
--   Id 2477 App.PosLayout                   'Visual'   Company 25
--   Id 2483 ButtonBar.ShowNewSale           'false'    Company 25
--   Id 2485 ButtonBar.ShowOrderName         'false'    Company 25
--   Id 2511 Order.EnableCustomOrderName     'false'    Company 25
--   Id 2512 Order.NameRequired              'false'    Company 25
--   Id 2513 Order.RequestNameAutomatically  'true'     Company 25
--   Id 3179 App.PosLayout                   'Standard' Company 27
--   Id 3185 ButtonBar.ShowNewSale           'false'    Company 27
--   Id 3187 ButtonBar.ShowOrderName         'true'     Company 27
--   Id 3213 Order.EnableCustomOrderName     'false'    Company 27
--   Id 3214 Order.NameRequired              'false'    Company 27
--   Id 3215 Order.RequestNameAutomatically  'false'    Company 27
--
-- NOTE: scoped by Name only, deliberately — the keys are dead for EVERY
-- company, not just 25/27, so a new tenant carrying them should lose them too.

BEGIN TRANSACTION;

DELETE FROM dbo.ApplicationProperty
WHERE Name IN (
    'App.PosLayout',
    'ButtonBar.ShowNewSale',
    'ButtonBar.ShowOrderName',
    'Order.EnableCustomOrderName',
    'Order.NameRequired',
    'Order.RequestNameAutomatically'
);

-- Expect 12 on the dev DB (6 keys x companies 25 and 27). Inspect, then COMMIT.
SELECT @@ROWCOUNT AS DeletedRows;

-- ROLLBACK;
COMMIT;


-- ── Local Drift DB (pos_app.sqlite) — run in DBeaver, app CLOSED ────────────
-- SQLite file locking: do not write while pos_app.exe holds the DB open.
--
-- DELETE FROM app_properties WHERE name IN (
--     'App.PosLayout',
--     'ButtonBar.ShowNewSale',
--     'ButtonBar.ShowOrderName',
--     'Order.EnableCustomOrderName',
--     'Order.NameRequired',
--     'Order.RequestNameAutomatically'
-- );
-- Expect 6 (company 25 only — this device has never held company 27).
