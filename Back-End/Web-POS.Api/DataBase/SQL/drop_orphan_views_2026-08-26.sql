-- Drops two views nothing reads: dbo.PaymentsView and dbo.DocumentItemPriceView.
--
-- Both are leftovers from an earlier reporting implementation. Every other view
-- in this folder is mapped as an entity in AppDbContext.cs and has a matching
-- .sql file here; these two have NEITHER — they exist only in the database.
--
-- ── HOW THAT WAS ESTABLISHED (re-run these before dropping) ──────────────────
--
-- 1. No other database object references them. Both return zero rows:
--
--      SELECT referencing_schema_name, referencing_entity_name
--      FROM sys.dm_sql_referencing_entities('dbo.PaymentsView', 'OBJECT');
--
--      SELECT referencing_schema_name, referencing_entity_name
--      FROM sys.dm_sql_referencing_entities('dbo.DocumentItemPriceView', 'OBJECT');
--
-- 2. No code references them. Grepped across Back-End, Front-End and
--    kitchen_display for both names in *.cs, *.dart, *.sql, *.json and *.ps1.
--    The single hit is `_PaymentsView` in
--    Front-End/lib/document/document_editor_screen.dart — a FLUTTER WIDGET
--    class that happens to share the name. It is not this view.
--
-- 3. Neither is in AppDbContext.cs, so EF never builds a query against them.
--
-- ── RECOVERY ────────────────────────────────────────────────────────────────
-- Their definitions as they stood on 2026-08-26 are at the bottom of this file.
-- If dropping is ever regretted, uncomment that block and run it.
--
-- Safe to re-run: each DROP is guarded, so a second run is a no-op.

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.PaymentsView', 'V') IS NOT NULL
    DROP VIEW dbo.PaymentsView;

IF OBJECT_ID('dbo.DocumentItemPriceView', 'V') IS NOT NULL
    DROP VIEW dbo.DocumentItemPriceView;

COMMIT;
GO

-- ── ROLLBACK ────────────────────────────────────────────────────────────────
-- Uncomment and run to put them back exactly as they were.
--
-- CREATE VIEW dbo.PaymentsView AS
-- SELECT
--     P.DocumentId,
--     STUFF(
--         (
--             SELECT ', ' + PT.Name
--             FROM dbo.Payment p_inner
--             INNER JOIN dbo.PaymentType PT ON PT.Id = p_inner.PaymentTypeId
--             WHERE p_inner.DocumentId = P.DocumentId
--             FOR XML PATH('')
--         ), 1, 2, ''
--     ) AS PaymentTypes
-- FROM
--     dbo.Payment P
-- GROUP BY
--     P.DocumentId;
-- GO
--
-- CREATE VIEW dbo.DocumentItemPriceView
-- AS
-- SELECT
--     DI.Id AS DocumentItemId,
--     -- If cart discount exists
--     CASE
--         WHEN D.Discount > 0
--         THEN
--             -- Percentage discount on cart
--             CASE
--                 WHEN D.DiscountType = 0
--                 -- Calculate cart percentage discount on previously calculated price with discount
--                 THEN (DI.PriceAfterDiscount / ROUND(100.0, 2)) * (ROUND(100.0, 2) - D.Discount)
--                 ELSE
--                 -- Cart fixed discount subtracted from price with tax
--                 DI.PriceAfterDiscount - (((D.Discount * ROUND(DI.Total, 2)) / (ROUND(D.Total, 2) + D.Discount)) / DI.Quantity)
--             END
--         ELSE
--             DI.PriceAfterDiscount
--     END AS Price
-- FROM
--     dbo.DocumentItem AS DI
-- INNER JOIN
--     dbo.Document AS D
--     ON D.Id = DI.DocumentId;
-- GO
