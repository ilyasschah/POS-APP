-- ============================================================
-- View: vw_HourlySalesByGroupRow
-- Purpose: Item-level sales rows with product group and hour,
--          used by the "Hourly Sales by Product Groups" report.
--          The API handler groups by (ProductGroup x Hour).
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_HourlySalesByGroupRow] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)              AS [Date],
    DATEPART(HOUR, d.DateCreated)     AS [Hour],
    d.CustomerId,
    d.WarehouseId,
    p.ProductGroupId,
    ISNULL(pg.Name, N'No group')     AS ProductGroup,
    di.TotalAfterDocumentDiscount     AS Amount
FROM  dbo.DocumentItem  di
INNER JOIN dbo.Document      d  ON di.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
INNER JOIN dbo.Product       p  ON di.ProductId     = p.Id
LEFT  JOIN dbo.ProductGroup  pg ON p.ProductGroupId = pg.Id
WHERE dt.Code = '200';   -- Sales documents only
GO
