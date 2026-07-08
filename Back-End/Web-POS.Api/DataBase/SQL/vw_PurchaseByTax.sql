-- Run this script once in SQL Server Management Studio (or Azure Data Studio)
-- to create the view used by the Purchase Tax report.

CREATE OR ALTER VIEW vw_PurchaseByTax AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                          AS [Date],
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    di.ProductId,
    p.ProductGroupId,
    dit.TaxId,
    ISNULL(t.Name, N'---')                                        AS TaxName,
    ROUND(di.PriceBeforeTaxAfterDiscount * di.Quantity, 2)       AS TotalBeforeTax,
    ISNULL(dit.Amount, 0)                                         AS TaxAmount,
    di.TotalAfterDocumentDiscount                                 AS Total
FROM  dbo.DocumentItem      di
INNER JOIN dbo.Document      d   ON di.DocumentId    = d.Id
INNER JOIN dbo.Product       p   ON di.ProductId     = p.Id
INNER JOIN dbo.DocumentType  dt  ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.DocumentItemTax dit ON di.Id          = dit.DocumentItemId
LEFT  JOIN dbo.Tax           t   ON dit.TaxId        = t.Id
WHERE dt.Code = '100';
