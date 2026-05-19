-- ============================================================
-- View: vw_DailySalesRow
-- Purpose: Raw per-payment rows for Sales and Refund documents,
--          used by the "Daily Sales" report. The API query
--          applies filters then groups by Date.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_DailySalesRow] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)  AS [Date],
    d.CustomerId,
    d.UserId,
    d.WarehouseId,
    p.Amount
FROM  dbo.Payment      p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code IN ('200', '220');   -- Sales and Refund documents
GO
