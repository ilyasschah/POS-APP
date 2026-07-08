-- ============================================================
-- View: vw_PurchaseByProduct
-- Purpose: Raw purchase line items used by the "Purchase by Product"
--          report. Mirrors vw_SalesByProduct with DocumentType Code 100.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_PurchaseByProduct] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                         AS [Date],
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    p.Id                                                         AS ProductId,
    ISNULL(p.Code, CAST(p.PLU AS NVARCHAR(50)))                AS ProductCode,
    p.Name                                                       AS ProductName,
    ISNULL(p.MeasurementUnit, N'')                             AS UOM,
    p.ProductGroupId,
    pg.Name                                                      AS ProductGroupName,
    di.Quantity,
    ROUND(di.PriceBeforeTaxAfterDiscount * di.Quantity, 2)     AS TotalBeforeTax,
    di.TotalAfterDocumentDiscount                               AS Total
FROM  dbo.DocumentItem  di
INNER JOIN dbo.Document      d  ON di.DocumentId    = d.Id
INNER JOIN dbo.Product       p  ON di.ProductId     = p.Id
LEFT  JOIN dbo.ProductGroup  pg ON p.ProductGroupId = pg.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code = '100';   -- DocumentType Code 100 = Purchase
GO
