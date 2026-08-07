-- ============================================================
-- Backfill: DocumentItem.TotalAfterDocumentDiscount
--
-- Until PosOrderCheckoutService.ApportionDocumentDiscount landed, checkout
-- persisted this column with whatever the client sent, and the client only
-- ever subtracted the ITEM discount. Every order-level reduction — manual
-- cart discount, loyalty points, promotions — was therefore missing from
-- the column that vw_DashboardSalesData, vw_SalesByProduct, vw_SalesByTax,
-- vw_ProfitRow and vw_SalesItemList all sum as revenue. Those reports read
-- gross where the documents and payments read collected.
--
-- This rewrites the historical rows to satisfy the same invariant the new
-- checkout code maintains:
--     SUM(DocumentItem.TotalAfterDocumentDiscount) == Document.Total
--
-- Scaled by each line's share of the gross, with the rounding remainder on
-- the last line so the sum is exact rather than a cent adrift.
--
-- Safe to re-run: every value is derived from DocumentItem.Total and
-- Document.Total, never from the column being written, and documents that
-- already reconcile are skipped by the HAVING clause.
--
-- Sales documents only. Refunds ('220') are written with the line total
-- equal to the header total already, and other document types don't carry
-- an order-level discount.
-- ============================================================
WITH doc AS (
    SELECT  d.Id,
            d.Total          AS DocTotal,
            SUM(di.Total)    AS Gross
    FROM        dbo.Document     d
    INNER JOIN  dbo.DocumentItem di ON di.DocumentId    = d.Id
    INNER JOIN  dbo.DocumentType dt ON dt.Id            = d.DocumentTypeId
    WHERE dt.Code = '200'
    GROUP BY d.Id, d.Total
    -- Only documents whose lines still overstate the header.
    HAVING SUM(di.Total) > d.Total
       AND SUM(di.Total) > 0
),
line AS (
    SELECT  di.Id,
            di.DocumentId,
            di.Total,
            doc.DocTotal,
            doc.Gross,
            ROW_NUMBER() OVER (PARTITION BY di.DocumentId ORDER BY di.Id) AS rn,
            COUNT(*)     OVER (PARTITION BY di.DocumentId)                AS cnt
    FROM       dbo.DocumentItem di
    INNER JOIN doc ON doc.Id = di.DocumentId
),
calc AS (
    SELECT  l.*,
            ROUND(  CAST(l.Total    AS decimal(18,4))
                  * CAST(l.DocTotal AS decimal(18,4))
                  / CAST(l.Gross    AS decimal(18,4)), 2) AS Scaled
    FROM line l
),
run AS (
    SELECT  c.*,
            SUM(c.Scaled) OVER (PARTITION BY c.DocumentId ORDER BY c.rn
                                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS PrevSum
    FROM calc c
)
UPDATE di
SET    di.TotalAfterDocumentDiscount =
           CASE WHEN r.rn = r.cnt
                -- Last line absorbs the remainder, so the column sums
                -- EXACTLY to Document.Total.
                THEN r.DocTotal - ISNULL(r.PrevSum, 0)
                ELSE r.Scaled
           END
FROM       dbo.DocumentItem di
INNER JOIN run r ON r.Id = di.Id;
GO

-- Verification: must return zero rows.
SELECT  d.Id,
        d.Number,
        d.Total                              AS DocumentTotal,
        SUM(di.TotalAfterDocumentDiscount)   AS LineSum
FROM        dbo.Document     d
INNER JOIN  dbo.DocumentItem di ON di.DocumentId = d.Id
INNER JOIN  dbo.DocumentType dt ON dt.Id         = d.DocumentTypeId
WHERE dt.Code = '200'
GROUP BY d.Id, d.Number, d.Total
HAVING SUM(di.TotalAfterDocumentDiscount) <> d.Total;
GO
