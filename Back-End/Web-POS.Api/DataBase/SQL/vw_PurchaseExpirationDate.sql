-- Run this script once in SSMS to create the view for the Purchase Expiration Date report.
-- The date-range filter (expirationDate >= startDate AND <= endDate) is applied in the query layer.

CREATE OR ALTER VIEW [dbo].[vw_PurchaseExpirationDate] AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                              AS [Date],
    d.Id                                                              AS DocumentId,
    d.Number                                                          AS DocumentNumber,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    di.ProductId,
    ISNULL(p.Code, CAST(p.PLU AS NVARCHAR(50)))                     AS ProductCode,
    p.Name                                                            AS ProductName,
    ISNULL(p.MeasurementUnit, N'')                                   AS UOM,
    p.ProductGroupId,
    CAST(di.Quantity AS DECIMAL(18,4))                               AS Quantity,
    COALESCE(c.Name, 'Unknown')                                       AS SupplierName,
    CAST(exp.ExpirationDate AS DATE)                                  AS ExpirationDate
FROM  dbo.DocumentItemExpirationDate exp
INNER JOIN dbo.DocumentItem  di ON di.Id          = exp.DocumentItemId
INNER JOIN dbo.[Document]    d  ON d.Id           = di.DocumentId
                                AND d.CompanyId   = exp.CompanyId
INNER JOIN dbo.DocumentType  dt ON dt.Id          = d.DocumentTypeId
                                AND dt.Code       = '100'
INNER JOIN dbo.Product       p  ON p.Id           = di.ProductId
                                AND p.CompanyId   = di.CompanyId
LEFT  JOIN dbo.Customer      c  ON c.Id           = d.CustomerId
                                AND c.CompanyId   = d.CompanyId
GO
