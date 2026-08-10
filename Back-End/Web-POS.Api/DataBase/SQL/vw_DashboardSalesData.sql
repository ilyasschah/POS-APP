-- ============================================================
-- View: vw_DashboardSalesData
-- Purpose: Powers the Dashboard screen (monthly/hourly sales,
--          top products, top groups, top customers).
--          Sales (DocumentType.Code = '200') count positively and
--          Refunds ('220') negatively, so every figure reports money
--          KEPT and a fully-refunded sale nets to zero — matching the
--          POS app's own dashboard, which nets refunds the same way.
--          Purchase (100), InventoryCount (300) etc. stay excluded.
--
-- ItemTotal reads TotalAfterDocumentDiscount. Checkout reconciles that
-- column so it sums EXACTLY to Document.Total — see
-- PosOrderCheckoutService.ApportionDocumentDiscount. Before that fix it
-- held the pre-discount value, and this view overstated every sale by
-- its full order-level discount.
--
-- SalesHour is the UTC hour: StockDate is written as DateTime.UtcNow.
-- GetDashboardDataQuery rotates the buckets into the caller's timezone,
-- so deliberately do NOT bake a timezone in here.
-- Run this script once on the database; no migration needed.
-- ============================================================
CREATE OR ALTER VIEW [dbo].[vw_DashboardSalesData] AS
SELECT
    d.CompanyId,
    d.Id                                                          AS DocumentId,
    d.Date                                                        AS [Date],
    YEAR(d.Date)                                                  AS SalesYear,
    MONTH(d.Date)                                                 AS SalesMonth,
    DATEPART(HOUR, d.StockDate)                                   AS SalesHour,  -- UTC hour; StockDate holds the full timestamp, Date is date-only
    p.Id                                                          AS ProductId,
    p.Name                                                        AS ProductName,
    -- Refund rows are stored POSITIVE (ProcessRefundCommand), so flip the
    -- sign here to net them out of the totals, trend, top products and
    -- top customers alike.
    CASE WHEN dt.Code = '220' THEN -di.Quantity
         ELSE di.Quantity END                                     AS Quantity,
    CASE WHEN dt.Code = '220' THEN -di.TotalAfterDocumentDiscount
         ELSE di.TotalAfterDocumentDiscount END                   AS ItemTotal,
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
WHERE dt.Code IN ('200', '220');   -- Sales (+) and Refunds (−)
GO
