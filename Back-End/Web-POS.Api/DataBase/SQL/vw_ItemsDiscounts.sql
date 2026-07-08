-- Run this script once in SSMS / Azure Data Studio.

CREATE OR ALTER VIEW vw_ItemsDiscounts AS
SELECT
    d.CompanyId,
    d.Date,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    di.ProductId,
    p.Code  AS ProductCode,
    p.Name  AS ProductName,
    CAST(di.Price * di.Quantity - di.Total AS DECIMAL(18,2)) AS TotalDiscount
FROM [Document] d
JOIN DocumentItem di ON di.DocumentId = d.Id
JOIN Product     p  ON p.Id           = di.ProductId
WHERE di.Price * di.Quantity - di.Total > 0.005;
