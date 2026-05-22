-- Run this script once in SSMS / Azure Data Studio.

CREATE OR ALTER VIEW vw_StockMovement AS
SELECT
    d.CompanyId,
    d.Date,
    d.UserId,
    di.ProductId,
    p.Code                              AS ProductCode,
    p.Name                              AS ProductName,
    CAST(di.Quantity AS DECIMAL(18,4))  AS Quantity
FROM [Document] d
JOIN DocumentItem di ON di.DocumentId = d.Id
JOIN Product     p  ON p.Id           = di.ProductId;
