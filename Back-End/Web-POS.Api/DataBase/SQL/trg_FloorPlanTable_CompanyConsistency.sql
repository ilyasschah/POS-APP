-- ============================================================
-- Trigger: trg_FloorPlanTable_CompanyConsistency
--          (table: dbo.FloorPlanTable)
-- Purpose: Multi-tenant integrity guard. A FloorPlanTable must belong
--          to the SAME company as the FloorPlan it sits on — blocks
--          cross-tenant table/floor-plan linkage on INSERT/UPDATE.
-- Idempotent (CREATE OR ALTER). Run once on the database; no EF
-- migration — triggers are managed as scripts in this folder.
-- ============================================================
CREATE OR ALTER TRIGGER [dbo].[trg_FloorPlanTable_CompanyConsistency]
    ON dbo.FloorPlanTable
    AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.FloorPlan fp ON fp.Id = i.FloorPlanId
        WHERE i.CompanyId <> fp.CompanyId
    )
    BEGIN
        RAISERROR('FloorPlanTable.CompanyId must match FloorPlan.CompanyId.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
