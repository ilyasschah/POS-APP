-- ============================================================
-- View: vw_SalesByPaymentType
-- Purpose: Raw payment rows linked to sales documents, used by
--          the "Sales by Payment Types" report. The API query
--          groups by (Date, PaymentTypeName) on top of this view.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_SalesByPaymentType] AS
SELECT
    p.CompanyId,
    CAST(d.Date AS DATE)   AS [Date],
    p.UserId,
    d.CustomerId,
    d.WarehouseId,
    pt.Id                  AS PaymentTypeId,
    pt.Name                AS PaymentTypeName,
    p.Amount
FROM  dbo.Payment      p
INNER JOIN dbo.Document      d  ON p.DocumentId     = d.Id
INNER JOIN dbo.PaymentType   pt ON p.PaymentTypeId  = pt.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code = '200';   -- DocumentType Code 200 = Sales
GO
