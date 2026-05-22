-- Run this script once in SQL Server Management Studio (or Azure Data Studio)
-- to create the view used by the Purchased Items Discounts report.

CREATE OR ALTER VIEW vw_PurchaseItemsDiscounts AS
SELECT
    d.CompanyId,
    d.Id                                                            AS DocumentId,
    d.Number                                                        AS DocumentNumber,
    d.Date,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    di.ProductId,
    p.Code                                                          AS ProductCode,
    p.Name                                                          AS ProductName,
    COALESCE(
        NULLIF(TRIM(COALESCE(u.FirstName, '') + ' ' + COALESCE(u.LastName, '')), ''),
        u.Username,
        CAST(d.UserId AS NVARCHAR(20))
    )                                                               AS UserName,
    COALESCE(c.Name, 'Unknown')                                     AS SupplierName,
    CAST(di.Quantity AS DECIMAL(18,4))                             AS Quantity,
    CAST(p.Cost * di.Quantity AS DECIMAL(18,2))                    AS Cost,
    CAST(di.Price * di.Quantity AS DECIMAL(18,2))                  AS TotalBeforeDiscount,
    CAST(di.Total AS DECIMAL(18,2))                                AS TotalAfterDiscount,
    di.Discount                                                     AS DiscountValue,
    di.DiscountType,
    CAST(di.Price * di.Quantity - di.Total AS DECIMAL(18,2))       AS TotalDiscount
FROM [Document] d
INNER JOIN DocumentType doctype ON doctype.Id = d.DocumentTypeId AND doctype.Code = '100'
JOIN DocumentItem di ON di.DocumentId = d.Id
JOIN Product      p  ON p.Id          = di.ProductId
LEFT JOIN [User]  u  ON u.Id          = d.UserId
LEFT JOIN Customer c ON c.Id = d.CustomerId AND c.CompanyId = d.CompanyId
WHERE di.Discount > 0;
