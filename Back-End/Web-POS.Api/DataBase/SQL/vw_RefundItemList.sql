-- ============================================================
-- View: vw_RefundItemList
-- Purpose: Refund line items with product and customer context,
--          used by the "Refunds" report.
-- Quantities and amounts are negated so they appear as negative
-- values on the report, reflecting the reversal of a sale.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_RefundItemList] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                                           AS [Date],
    d.DateCreated,
    d.Number                                                                       AS DocumentNumber,
    d.ReferenceDocumentNumber                                                      AS RefNumber,
    d.OrderNumber,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    c.Code                                                                         AS CustomerCode,
    ISNULL(c.Name, N'Unknown')                                                    AS CustomerName,
    p.Id                                                                           AS ProductId,
    ISNULL(p.Code, CAST(p.PLU AS NVARCHAR(50)))                                AS ProductCode,
    p.Name                                                                         AS ProductName,
    ISNULL(p.MeasurementUnit, N'')                                              AS UOM,
    p.ProductGroupId,
    -di.Quantity                                                                   AS Quantity,
    -ROUND(di.PriceBeforeTaxAfterDiscount * di.Quantity, 2)                     AS TotalBeforeTax,
    -ROUND(di.TotalAfterDocumentDiscount
           - di.PriceBeforeTaxAfterDiscount * di.Quantity, 2)                   AS TotalTax,
    -di.TotalAfterDocumentDiscount                                                 AS Total
FROM  dbo.DocumentItem  di
INNER JOIN dbo.Document      d  ON di.DocumentId    = d.Id
INNER JOIN dbo.Product       p  ON di.ProductId     = p.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId     = c.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code = '220';   -- DocumentType Code 220 = Refund
GO
