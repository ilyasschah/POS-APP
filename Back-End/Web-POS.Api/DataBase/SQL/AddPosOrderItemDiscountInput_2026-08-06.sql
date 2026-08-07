IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260430101242_AddUserIdToBooking'
)
BEGIN
    ALTER TABLE [Booking] ADD [UserId] int NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260430101242_AddUserIdToBooking'
)
BEGIN
    CREATE INDEX [IX_Booking_UserId] ON [Booking] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260430101242_AddUserIdToBooking'
)
BEGIN
    ALTER TABLE [Booking] ADD CONSTRAINT [FK_Booking_User_UserId] FOREIGN KEY ([UserId]) REFERENCES [User] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260430101242_AddUserIdToBooking'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260430101242_AddUserIdToBooking', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260507220745_MultiTableBookings'
)
BEGIN
    DECLARE @var nvarchar(max);
    SELECT @var = QUOTENAME([d].[name])
    FROM [sys].[default_constraints] [d]
    INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
    WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Booking]') AND [c].[name] = N'FloorPlanTableId');
    IF @var IS NOT NULL EXEC(N'ALTER TABLE [Booking] DROP CONSTRAINT ' + @var + ';');
    ALTER TABLE [Booking] DROP COLUMN [FloorPlanTableId];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260507220745_MultiTableBookings'
)
BEGIN
    ALTER TABLE [Counter] ADD [CompanyId] int NOT NULL DEFAULT 0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260507220745_MultiTableBookings'
)
BEGIN
    ALTER TABLE [Booking] ADD [TableIds] nvarchar(1000) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260507220745_MultiTableBookings'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260507220745_MultiTableBookings', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260516214546_AddWarehouseCompany'
)
BEGIN
    CREATE TABLE [UserDevicePins] (
        [Id] int NOT NULL IDENTITY,
        [UserId] int NOT NULL,
        [CompanyId] int NOT NULL,
        [DeviceId] nvarchar(max) NOT NULL,
        [HashedPin] nvarchar(max) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_UserDevicePins] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_UserDevicePins_User_UserId] FOREIGN KEY ([UserId]) REFERENCES [User] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260516214546_AddWarehouseCompany'
)
BEGIN
    CREATE INDEX [IX_UserDevicePins_UserId] ON [UserDevicePins] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260516214546_AddWarehouseCompany'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260516214546_AddWarehouseCompany', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260526213218_AddPosOrderDateCreated'
)
BEGIN
    ALTER TABLE [PosOrder] ADD [DateCreated] datetime2 NOT NULL DEFAULT (GETUTCDATE());
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260526213218_AddPosOrderDateCreated'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260526213218_AddPosOrderDateCreated', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [User] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [Tax] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [Promotion] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [ProductGroup] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [Product] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [PaymentType] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [FloorPlanTable] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [FloorPlan] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [Customer] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    ALTER TABLE [ApplicationProperty] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260527195145_Add_LastModified_To_Syncable_Entities'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260527195145_Add_LastModified_To_Syncable_Entities', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607121236_AddLoyaltyCardPointsSync'
)
BEGIN
    ALTER TABLE [LoyaltyCard] ADD [LastModified] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607121236_AddLoyaltyCardPointsSync'
)
BEGIN
    ALTER TABLE [LoyaltyCard] ADD [Points] decimal(18,2) NOT NULL DEFAULT 0.0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607121236_AddLoyaltyCardPointsSync'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260607121236_AddLoyaltyCardPointsSync', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607192911_AddShiftAndTimeClock'
)
BEGIN
    CREATE TABLE [Shift] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [UserId] int NOT NULL,
        [OpenedAt] datetime2 NOT NULL,
        [ClosedAt] datetime2 NULL,
        [StartingCash] decimal(18,2) NOT NULL,
        [ActualEndingCash] decimal(18,2) NULL,
        [Status] int NOT NULL,
        [LastModified] datetime2 NOT NULL,
        CONSTRAINT [PK_Shift] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607192911_AddShiftAndTimeClock'
)
BEGIN
    CREATE TABLE [TimeClockEntry] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [UserId] int NOT NULL,
        [ClockInTime] datetime2 NOT NULL,
        [ClockOutTime] datetime2 NULL,
        [LastModified] datetime2 NOT NULL,
        CONSTRAINT [PK_TimeClockEntry] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260607192911_AddShiftAndTimeClock'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260607192911_AddShiftAndTimeClock', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260625101923_AddDiscountLine'
)
BEGIN
    CREATE TABLE [DiscountLine] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [DocumentId] int NOT NULL,
        [ProductId] int NULL,
        [Source] nvarchar(max) NOT NULL,
        [SourceRefId] int NULL,
        [Value] decimal(18,2) NOT NULL,
        [ValueType] int NOT NULL,
        [Amount] decimal(18,2) NOT NULL,
        [Sequence] int NOT NULL,
        [Label] nvarchar(max) NULL,
        [DateCreated] datetime2 NOT NULL,
        CONSTRAINT [PK_DiscountLine] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DiscountLine_Document_DocumentId] FOREIGN KEY ([DocumentId]) REFERENCES [Document] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260625101923_AddDiscountLine'
)
BEGIN
    CREATE INDEX [IX_DiscountLine_DocumentId] ON [DiscountLine] ([DocumentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260625101923_AddDiscountLine'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260625101923_AddDiscountLine', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260716083341_DropPosPrinterSelectionTables'
)
BEGIN
    DROP TABLE [PosPrinterSelectionSettings];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260716083341_DropPosPrinterSelectionTables'
)
BEGIN
    DROP TABLE [PosPrinterSelection];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260716083341_DropPosPrinterSelectionTables'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260716083341_DropPosPrinterSelectionTables', N'10.0.9');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806174002_AddPosOrderItemDiscountInput'
)
BEGIN
    ALTER TABLE [PosOrderItem] ADD [DiscountInputType] int NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806174002_AddPosOrderItemDiscountInput'
)
BEGIN
    ALTER TABLE [PosOrderItem] ADD [DiscountInputValue] decimal(18,2) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806174002_AddPosOrderItemDiscountInput'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260806174002_AddPosOrderItemDiscountInput', N'10.0.9');
END;

COMMIT;
GO

