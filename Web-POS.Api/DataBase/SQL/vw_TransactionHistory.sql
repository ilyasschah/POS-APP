-- ============================================================
-- View: vw_TransactionHistory
-- Purpose: Per-partner ledger combining document and payment
--          transactions for the "Transaction history" finance report.
-- Run this script once on the database; no migration needed.
-- Credit/Debit convention (from the business partner's perspective):
--   Sales       → Debit   (customer owes us)
--   Refund      → Credit  (we return money to customer)
--   Purchase    → Credit  (supplier gives goods, we owe them)
--   Stock Return→ Debit   (return goods to supplier, debt reduced)
--   Pmt/Sales   → Credit  (customer paid = "Payment received")
--   Pmt/Purchase→ Debit   (we paid supplier = "Payment to supplier")
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_TransactionHistory] AS

-- Sales documents (Code='200') → Debit
SELECT
    d.CompanyId,
    d.CustomerId,
    c.Name                          AS PartnerName,
    CAST(d.Date AS DATE)            AS [Date],
    N'Sales'                        AS TransactionType,
    d.Number                        AS RefNumber,
    CAST(0 AS decimal(18,2))        AS Credit,
    d.Total                         AS Debit
FROM  dbo.Document      d
INNER JOIN dbo.DocumentType dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer     c  ON d.CustomerId     = c.Id
WHERE dt.Code = '200'
  AND d.CustomerId IS NOT NULL

UNION ALL

-- Refund documents (Code='220') → Credit
SELECT
    d.CompanyId,
    d.CustomerId,
    c.Name,
    CAST(d.Date AS DATE),
    N'Refund',
    d.Number,
    d.Total,
    CAST(0 AS decimal(18,2))
FROM  dbo.Document      d
INNER JOIN dbo.DocumentType dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer     c  ON d.CustomerId     = c.Id
WHERE dt.Code = '220'
  AND d.CustomerId IS NOT NULL

UNION ALL

-- Purchase documents (Code='100') → Credit
SELECT
    d.CompanyId,
    d.CustomerId,
    c.Name,
    CAST(d.Date AS DATE),
    N'Purchase',
    d.Number,
    d.Total,
    CAST(0 AS decimal(18,2))
FROM  dbo.Document      d
INNER JOIN dbo.DocumentType dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer     c  ON d.CustomerId     = c.Id
WHERE dt.Code = '100'
  AND d.CustomerId IS NOT NULL

UNION ALL

-- Stock Return documents (Code='120') → Debit
SELECT
    d.CompanyId,
    d.CustomerId,
    c.Name,
    CAST(d.Date AS DATE),
    N'Stock Return',
    d.Number,
    CAST(0 AS decimal(18,2)),
    d.Total
FROM  dbo.Document      d
INNER JOIN dbo.DocumentType dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer     c  ON d.CustomerId     = c.Id
WHERE dt.Code = '120'
  AND d.CustomerId IS NOT NULL

UNION ALL

-- Payments linked to Sales docs → "Payment received" → Credit
SELECT
    p.CompanyId,
    d.CustomerId,
    c.Name,
    CAST(p.Date AS DATE),
    N'Payment received',
    d.Number,
    p.Amount,
    CAST(0 AS decimal(18,2))
FROM  dbo.Payment       p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId     = c.Id
WHERE dt.Code = '200'
  AND d.CustomerId IS NOT NULL

UNION ALL

-- Payments linked to Purchase docs → "Payment to supplier" → Debit
SELECT
    p.CompanyId,
    d.CustomerId,
    c.Name,
    CAST(p.Date AS DATE),
    N'Payment to supplier',
    d.Number,
    CAST(0 AS decimal(18,2)),
    p.Amount
FROM  dbo.Payment       p
INNER JOIN dbo.Document      d  ON p.DocumentId    = d.Id
INNER JOIN dbo.DocumentType  dt ON d.DocumentTypeId = dt.Id
LEFT  JOIN dbo.Customer      c  ON d.CustomerId     = c.Id
WHERE dt.Code = '100'
  AND d.CustomerId IS NOT NULL;
GO
