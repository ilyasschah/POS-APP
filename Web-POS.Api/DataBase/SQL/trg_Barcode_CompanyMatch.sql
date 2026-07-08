-- ============================================================
-- Trigger: trg_Barcode_CompanyMatch   (table: dbo.Barcode)
-- Purpose: Multi-tenant integrity guard. A Barcode row must belong
--          to the SAME company as the Product it points at — blocks
--          cross-tenant barcode/product linkage on INSERT/UPDATE.
-- Idempotent (CREATE OR ALTER). Run once on the database; no EF
-- migration — triggers are managed as scripts in this folder.
-- ============================================================
CREATE OR ALTER TRIGGER [dbo].[trg_Barcode_CompanyMatch]
    ON dbo.Barcode
    AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Product p ON p.Id = i.ProductId
        WHERE i.CompanyId <> p.CompanyId
    )
    BEGIN
        RAISERROR('Barcode.CompanyId must match Product.CompanyId', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
