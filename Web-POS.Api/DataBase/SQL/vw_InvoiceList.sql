-- ============================================================
-- View: vw_InvoiceList
-- Purpose: One row per payment on Sales and Refund documents,
--          used by the "Invoice list" report.
--          Refund payments already carry a negative Amount.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_InvoiceList] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)         AS [Date],
    d.Number                     AS DocumentNumber,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    ISNULL(c.Name, N'Unknown')  AS CustomerName,
    pt.Name                      AS PaymentMethodName,
    p.Amount                     AS Total
FROM  dbo.Payment      p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId    = c.Id
INNER JOIN dbo.PaymentType   pt ON p.PaymentTypeId = pt.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
WHERE dt.Code IN ('200', '220');   -- Sales and Refund documents
GO
