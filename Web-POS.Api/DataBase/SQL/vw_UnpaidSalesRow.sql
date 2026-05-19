-- ============================================================
-- View: vw_UnpaidSalesRow
-- Purpose: One row per unpaid/partial Sales document with the
--          total payments already aggregated, used by the
--          "Unpaid Sales" report.
-- PaidStatus 0 = Unpaid, 2 = Partial.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_UnpaidSalesRow] AS
SELECT
    d.CompanyId,
    d.Id                                         AS DocumentId,
    CAST(d.Date AS DATE)                         AS [Date],
    CAST(d.DueDate AS DATE)                      AS DueDate,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    d.Number                                     AS DocumentNumber,
    ISNULL(c.Name, N'Unknown')                  AS CustomerName,
    d.Total                                      AS DocumentTotal,
    ISNULL(SUM(p.Amount), 0)                     AS TotalPaid,
    d.Total - ISNULL(SUM(p.Amount), 0)           AS TotalUnpaid
FROM  dbo.Document      d
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId     = c.Id
LEFT  JOIN dbo.Payment       p  ON p.DocumentId     = d.Id
WHERE dt.Code = '200'
  AND d.PaidStatus IN (0, 2)
GROUP BY
    d.Id,
    d.CompanyId,
    CAST(d.Date AS DATE),
    CAST(d.DueDate AS DATE),
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    d.Number,
    c.Name,
    d.Total;
GO
