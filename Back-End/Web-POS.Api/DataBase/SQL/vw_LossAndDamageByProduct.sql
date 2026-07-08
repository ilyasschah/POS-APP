-- ============================================================
-- View: vw_LossAndDamageByProduct
-- Purpose: Raw loss-and-damage line items used by the
--          "Loss and Damage by Product" report.
--          Mirrors vw_StockReturnByProduct with DocumentType Code 400.
-- Run this script once in SSMS; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_LossAndDamageByProduct] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                         AS [Date],
    d.UserId,
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
WHERE dt.Code = '400';   -- DocumentType Code 400 = Loss and Damage
GO
