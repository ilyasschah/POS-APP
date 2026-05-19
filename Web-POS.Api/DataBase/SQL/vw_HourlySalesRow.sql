-- ============================================================
-- View: vw_HourlySalesRow
-- Purpose: Raw per-payment rows for Sales documents with the
--          hour extracted from DateCreated, used by the
--          "Hourly Sales" report. The API handler groups by
--          Hour and counts distinct DocumentIds in memory.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_HourlySalesRow] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)              AS [Date],
    DATEPART(HOUR, d.DateCreated)     AS [Hour],
    d.CustomerId,
    d.WarehouseId,
    d.Id                              AS DocumentId,
    p.Amount
FROM  dbo.Payment      p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code = '200';   -- Sales documents only
GO
