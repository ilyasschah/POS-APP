BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE TABLE [DocumentItemModifier] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [DocumentItemId] int NOT NULL,
        [ModifierOptionId] int NULL,
        [GroupName] nvarchar(100) NULL,
        [Name] nvarchar(100) NOT NULL,
        [AdditionalPrice] decimal(18,2) NOT NULL,
        [Rank] int NOT NULL,
        CONSTRAINT [PK_DocumentItemModifier] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentItemModifier_Company_CompanyId] FOREIGN KEY ([CompanyId]) REFERENCES [Company] ([Id]),
        CONSTRAINT [FK_DocumentItemModifier_DocumentItem_DocumentItemId] FOREIGN KEY ([DocumentItemId]) REFERENCES [DocumentItem] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE TABLE [ModifierGroup] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [Name] nvarchar(100) NOT NULL,
        [MinSelections] int NOT NULL,
        [MaxSelections] int NOT NULL,
        [AllowsFreeText] bit NOT NULL,
        [Rank] int NOT NULL,
        [IsEnabled] bit NOT NULL,
        [LastModified] datetime2 NOT NULL,
        CONSTRAINT [PK_ModifierGroup] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ModifierGroup_Company_CompanyId] FOREIGN KEY ([CompanyId]) REFERENCES [Company] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE TABLE [PosOrderItemModifier] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [PosOrderItemId] int NOT NULL,
        [ModifierOptionId] int NULL,
        [GroupName] nvarchar(100) NULL,
        [Name] nvarchar(100) NOT NULL,
        [AdditionalPrice] decimal(18,2) NOT NULL,
        [Rank] int NOT NULL,
        CONSTRAINT [PK_PosOrderItemModifier] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_PosOrderItemModifier_Company_CompanyId] FOREIGN KEY ([CompanyId]) REFERENCES [Company] ([Id]),
        CONSTRAINT [FK_PosOrderItemModifier_PosOrderItem_PosOrderItemId] FOREIGN KEY ([PosOrderItemId]) REFERENCES [PosOrderItem] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE TABLE [ModifierOption] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [ModifierGroupId] int NOT NULL,
        [Name] nvarchar(100) NOT NULL,
        [AdditionalPrice] decimal(18,2) NOT NULL,
        [Rank] int NOT NULL,
        [IsEnabled] bit NOT NULL,
        [LastModified] datetime2 NOT NULL,
        CONSTRAINT [PK_ModifierOption] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ModifierOption_Company_CompanyId] FOREIGN KEY ([CompanyId]) REFERENCES [Company] ([Id]),
        CONSTRAINT [FK_ModifierOption_ModifierGroup_ModifierGroupId] FOREIGN KEY ([ModifierGroupId]) REFERENCES [ModifierGroup] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE TABLE [ProductModifierGroup] (
        [Id] int NOT NULL IDENTITY,
        [CompanyId] int NOT NULL,
        [ProductId] int NOT NULL,
        [ModifierGroupId] int NOT NULL,
        [Rank] int NOT NULL,
        [LastModified] datetime2 NOT NULL,
        CONSTRAINT [PK_ProductModifierGroup] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ProductModifierGroup_Company_CompanyId] FOREIGN KEY ([CompanyId]) REFERENCES [Company] ([Id]),
        CONSTRAINT [FK_ProductModifierGroup_ModifierGroup_ModifierGroupId] FOREIGN KEY ([ModifierGroupId]) REFERENCES [ModifierGroup] ([Id]),
        CONSTRAINT [FK_ProductModifierGroup_Product_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [Product] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_DocumentItemModifier_CompanyId_ModifierOptionId] ON [DocumentItemModifier] ([CompanyId], [ModifierOptionId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_DocumentItemModifier_DocumentItemId_Rank] ON [DocumentItemModifier] ([DocumentItemId], [Rank]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_ModifierGroup_CompanyId_Rank] ON [ModifierGroup] ([CompanyId], [Rank]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_ModifierOption_CompanyId] ON [ModifierOption] ([CompanyId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_ModifierOption_ModifierGroupId_Rank] ON [ModifierOption] ([ModifierGroupId], [Rank]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_PosOrderItemModifier_CompanyId] ON [PosOrderItemModifier] ([CompanyId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_PosOrderItemModifier_PosOrderItemId_Rank] ON [PosOrderItemModifier] ([PosOrderItemId], [Rank]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_ProductModifierGroup_CompanyId_ProductId_Rank] ON [ProductModifierGroup] ([CompanyId], [ProductId], [Rank]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE INDEX [IX_ProductModifierGroup_ModifierGroupId] ON [ProductModifierGroup] ([ModifierGroupId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ProductModifierGroup_ProductId_ModifierGroupId] ON [ProductModifierGroup] ([ProductId], [ModifierGroupId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260824223716_AddModifiers'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260824223716_AddModifiers', N'10.0.11');
END;

COMMIT;
GO

