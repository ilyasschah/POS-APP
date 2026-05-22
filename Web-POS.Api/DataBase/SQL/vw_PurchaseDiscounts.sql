-- Run this script once in SQL Server Management Studio (or Azure Data Studio)
-- to create the view used by the Purchase Discounts report.

CREATE OR ALTER VIEW vw_PurchaseDiscounts AS
SELECT
    d.CompanyId,
    d.Id                                                            AS DocumentId,
    d.Number                                                        AS DocumentNumber,
    d.Date,
    d.UserId,
    d.CustomerId,
    COALESCE(
        NULLIF(TRIM(COALESCE(u.FirstName, '') + ' ' + COALESCE(u.LastName, '')), ''),
        u.Username,
        CAST(d.UserId AS NVARCHAR(20))
    )                                                               AS UserName,
    COALESCE(c.Name, 'Unknown')                                     AS SupplierName,
    dt.TotalBeforeDiscount,
    CAST(
        CASE
            WHEN d.Discount > 0 AND d.DiscountType = 1             -- fixed amount
                THEN dt.ItemsTotal - d.Discount
            WHEN d.Discount > 0 AND d.DiscountType = 0             -- percentage
                THEN dt.ItemsTotal * (1 - d.Discount / 100.0)
            ELSE dt.ItemsTotal
        END
    AS DECIMAL(18,2))                                               AS TotalAfterDiscount,
    CAST(
        dt.TotalBeforeDiscount -
        CASE
            WHEN d.Discount > 0 AND d.DiscountType = 1
                THEN dt.ItemsTotal - d.Discount
            WHEN d.Discount > 0 AND d.DiscountType = 0
                THEN dt.ItemsTotal * (1 - d.Discount / 100.0)
            ELSE dt.ItemsTotal
        END
    AS DECIMAL(18,2))                                               AS DiscountGranted
FROM [Document] d
INNER JOIN DocumentType doctype ON doctype.Id = d.DocumentTypeId AND doctype.Code = '100'
JOIN (
    SELECT
        DocumentId,
        CAST(SUM(Price * Quantity) AS DECIMAL(18,2)) AS TotalBeforeDiscount,
        CAST(SUM(Total)            AS DECIMAL(18,2)) AS ItemsTotal
    FROM DocumentItem
    GROUP BY DocumentId
) dt ON dt.DocumentId = d.Id
LEFT JOIN [User]   u ON u.Id = d.UserId
LEFT JOIN Customer c ON c.Id = d.CustomerId AND c.CompanyId = d.CompanyId
WHERE
    dt.TotalBeforeDiscount -
    CASE
        WHEN d.Discount > 0 AND d.DiscountType = 1
            THEN dt.ItemsTotal - d.Discount
        WHEN d.Discount > 0 AND d.DiscountType = 0
            THEN dt.ItemsTotal * (1 - d.Discount / 100.0)
        ELSE dt.ItemsTotal
    END > 0.005;
