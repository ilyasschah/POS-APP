-- ============================================================
-- View: vw_DashboardSalesData
-- Purpose: Powers the Dashboard screen (monthly/hourly sales,
--          top products, top groups, top customers).
--          Only Sales documents (DocumentType.Code = '200') are
--          included — Purchase, InventoryCount, Refund, etc. are
--          intentionally excluded.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_DashboardSalesData] AS
SELECT
    d.CompanyId,
    d.Id                                                          AS DocumentId,
    d.Date                                                        AS [Date],
    YEAR(d.Date)                                                  AS SalesYear,
    MONTH(d.Date)                                                 AS SalesMonth,
    DATEPART(HOUR, d.StockDate)                                   AS SalesHour,  -- StockDate holds full timestamp; Date is date-only
    p.Id                                                          AS ProductId,
    p.Name                                                        AS ProductName,
    di.Quantity,
    di.TotalAfterDocumentDiscount                                 AS ItemTotal,
    pg.Id                                                         AS ProductGroupId,
    pg.Name                                                       AS ProductGroupName,
    d.CustomerId,
    c.Name                                                        AS CustomerName
FROM  dbo.DocumentItem  di
INNER JOIN dbo.Document      d  ON di.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
INNER JOIN dbo.Product       p  ON di.ProductId     = p.Id
LEFT  JOIN dbo.ProductGroup  pg ON p.ProductGroupId = pg.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId     = c.Id
WHERE dt.Code = '200';   -- Sales documents only (code 200); excludes Purchase (100), InventoryCount (300), etc.
GO
