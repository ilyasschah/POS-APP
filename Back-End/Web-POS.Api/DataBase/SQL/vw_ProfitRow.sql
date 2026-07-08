-- ============================================================
-- View: vw_ProfitRow
-- Purpose: Sales item rows with product cost, used by the
--          "Profit & Margin" report. The API handler groups
--          by product in memory.
-- Cost = ProductCost * Quantity (total cost for the line).
-- Total = TotalAfterDocumentDiscount (total sales revenue).
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_ProfitRow] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                              AS [Date],
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    p.Id                                                              AS ProductId,
    ISNULL(p.Code, CAST(p.PLU AS NVARCHAR(50)))                   AS ProductCode,
    p.Name                                                            AS ProductName,
    p.ProductGroupId,
    di.Quantity,
    ROUND(di.ProductCost * di.Quantity, 2)                          AS Cost,
    di.TotalAfterDocumentDiscount                                     AS Total
FROM  dbo.DocumentItem  di
INNER JOIN dbo.Document      d  ON di.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
INNER JOIN dbo.Product       p  ON di.ProductId     = p.Id
WHERE dt.Code = '200';   -- Sales documents only
GO
