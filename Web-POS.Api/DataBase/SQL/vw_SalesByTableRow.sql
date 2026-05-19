-- ============================================================
-- View: vw_SalesByTableRow
-- Purpose: Raw per-payment rows linked to a table/order number,
--          used by the "Sales by Table / Order Number" report.
--          The API handler groups by OrderNumber in memory.
--          Includes Sales and Refund documents so totals are net.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_SalesByTableRow] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)          AS [Date],
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    d.OrderNumber,
    d.Id                          AS DocumentId,
    p.Amount
FROM  dbo.Payment      p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code IN ('200', '220')
  AND d.OrderNumber IS NOT NULL
  AND d.OrderNumber <> '';
GO
