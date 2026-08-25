BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260825122541_AddModifierGroupIcon'
)
BEGIN
    ALTER TABLE [ModifierGroup] ADD [IconKey] nvarchar(40) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260825122541_AddModifierGroupIcon'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260825122541_AddModifierGroupIcon', N'10.0.11');
END;

COMMIT;
GO

