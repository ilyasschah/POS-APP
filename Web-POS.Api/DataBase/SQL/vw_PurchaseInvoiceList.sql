-- Run this script once in SQL Server Management Studio (or Azure Data Studio)
-- to create the view used by the Purchase Invoice List report.

CREATE OR ALTER VIEW vw_PurchaseInvoiceList AS
SELECT
    d.CompanyId,
    CAST(d.Date AS DATE)                                            AS [Date],
    d.Id                                                            AS DocumentId,
    d.Number                                                        AS DocumentNumber,
    d.ReferenceDocumentNumber                                       AS ExternalDocument,
    d.UserId,
    d.CustomerId,
    d.WarehouseId,
    COALESCE(c.Name, 'Unknown')                                     AS SupplierName,
    CAST(d.Total AS DECIMAL(18,2))                                  AS Total
FROM [Document] d
INNER JOIN DocumentType dt ON dt.Id = d.DocumentTypeId AND dt.Code = '100'
LEFT JOIN Customer c ON c.Id = d.CustomerId AND c.CompanyId = d.CompanyId;
