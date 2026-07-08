-- ============================================================
-- Trigger: trg_Document_CompanyConsistency   (table: dbo.Document)
-- Purpose: Multi-tenant integrity guard on INSERT/UPDATE of a Document:
--            1. Document.CompanyId must match its Warehouse's CompanyId.
--            2. If CustomerId is set, it must match the Customer's CompanyId.
--          Either mismatch rolls the transaction back.
-- NOTE: the Warehouse check JOINs dbo.Warehouse directly — there is NO
--       'WarehouseCompany' table (Warehouse.CompanyId is a direct FK). An
--       earlier version referenced a non-existent 'dbo.WarehouseCompany'
--       and broke checkout ("Invalid object name 'dbo.WarehouseCompany'").
-- Idempotent (CREATE OR ALTER). Run once on the database; no EF
-- migration — triggers are managed as scripts in this folder.
-- ============================================================
CREATE OR ALTER TRIGGER [dbo].[trg_Document_CompanyConsistency]
    ON [dbo].[Document]
    AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Warehouse company must match Document company
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Warehouse w ON w.Id = i.WarehouseId
        WHERE i.CompanyId <> w.CompanyId
    )
    BEGIN
        RAISERROR('Document.CompanyId must match the company of its Warehouse.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- If a Customer is set, also require the customer's company to match
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Customer c ON c.Id = i.CustomerId
        WHERE i.CustomerId IS NOT NULL AND i.CompanyId <> c.CompanyId
    )
    BEGIN
        RAISERROR('Document.CompanyId must match Customer.CompanyId when CustomerId is set.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
