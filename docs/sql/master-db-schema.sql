-- ============================================================================
-- Master SaaS control-plane database (ADR-002, Pillar 1)
-- Run once on the SQL Server. Kept SEPARATE from the tenant data ('web-pos')
-- so the per-company cascade delete can never touch billing/device records.
-- The API points at this via the "MasterConnection" connection string.
-- ============================================================================

-- The COLLATE is explicit on purpose. Without it CREATE DATABASE inherits the
-- HOST SERVER's collation, which is how dev and production drifted apart:
-- 'web-pos' carries SQL_Latin1_General_CP1_CI_AS (it predates the current dev
-- box), while ILYASS-DESK's server collation is Latin1_General_CI_AS, so the
-- dev copy of this database silently came out in the other collation.
-- Pinning it to match 'web-pos' keeps every database, plus tempdb, on one
-- collation -- otherwise any join between a table here and a #temp table or a
-- 'web-pos' string column fails with "Cannot resolve the collation conflict".
IF DB_ID('web-pos-master') IS NULL
    CREATE DATABASE [web-pos-master] COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE [web-pos-master];
GO

-- ── Tenant: one row per customer business, keyed to web-pos dbo.Company.Id ──
IF OBJECT_ID('dbo.Tenant') IS NULL
CREATE TABLE dbo.Tenant (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId       INT          NOT NULL,
    Name            NVARCHAR(255) NOT NULL,
    Status          NVARCHAR(30) NOT NULL CONSTRAINT DF_Tenant_Status DEFAULT('active'),
    CreatedAt       DATETIME2    NOT NULL CONSTRAINT DF_Tenant_CreatedAt DEFAULT(SYSUTCDATETIME()),
    ReviewFlaggedAt DATETIME2    NULL,
    CONSTRAINT UQ_Tenant_CompanyId UNIQUE (CompanyId)
);
GO

-- ── Subscription: Stripe billing + paid seat allowance per tenant ──
IF OBJECT_ID('dbo.Subscription') IS NULL
CREATE TABLE dbo.Subscription (
    Id                   INT IDENTITY(1,1) PRIMARY KEY,
    TenantId             INT          NOT NULL,
    StripeCustomerId     NVARCHAR(100) NULL,
    StripeSubscriptionId NVARCHAR(100) NULL,
    PriceTier            NVARCHAR(50)  NULL,
    SeatAllowance        INT          NOT NULL CONSTRAINT DF_Subscription_Seats DEFAULT(1),
    CurrentPeriodEnd     DATETIME2    NULL,
    BillingStatus        NVARCHAR(30) NOT NULL CONSTRAINT DF_Subscription_Status DEFAULT('trialing'),
    LastModified         DATETIME2    NOT NULL CONSTRAINT DF_Subscription_LM DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT UQ_Subscription_TenantId UNIQUE (TenantId),
    CONSTRAINT FK_Subscription_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(Id) ON DELETE CASCADE
);
GO

-- ── DeviceRegistry: registered terminals (hashed hardware fingerprint) ──
IF OBJECT_ID('dbo.DeviceRegistry') IS NULL
CREATE TABLE dbo.DeviceRegistry (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    TenantId     INT          NOT NULL,
    CompanyId    INT          NOT NULL,
    DeviceId     NVARCHAR(128) NOT NULL,
    DeviceName   NVARCHAR(255) NULL,
    Status       NVARCHAR(20) NOT NULL CONSTRAINT DF_Device_Status DEFAULT('active'),
    RegisteredAt DATETIME2    NOT NULL CONSTRAINT DF_Device_Reg DEFAULT(SYSUTCDATETIME()),
    LastSeenAt   DATETIME2    NOT NULL CONSTRAINT DF_Device_Seen DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT UQ_Device_Tenant_DeviceId UNIQUE (TenantId, DeviceId),
    CONSTRAINT FK_Device_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(Id) ON DELETE CASCADE
);
GO

-- ── AdminUser: back-office operator accounts for the /admin portal ──
-- These administer EVERY company, which is why they live here and not in
-- web-pos: the per-company cascade delete must never be able to reach them.
-- Unrelated to dbo.PosUser in web-pos, which is a cashier of one company.
-- Kept in sync with the self-healing block in Program.cs (Api.Admin.AdminUserSeeder).
IF OBJECT_ID('dbo.AdminUser') IS NULL
CREATE TABLE dbo.AdminUser (
    Id                 INT IDENTITY(1,1) PRIMARY KEY,
    Username           NVARCHAR(100) NOT NULL,
    PasswordHash       NVARCHAR(255) NOT NULL,   -- BCrypt. Never plaintext.
    DisplayName        NVARCHAR(255) NULL,
    IsActive           BIT       NOT NULL CONSTRAINT DF_AdminUser_IsActive DEFAULT(1),
    MustChangePassword BIT       NOT NULL CONSTRAINT DF_AdminUser_MustChange DEFAULT(0),
    CreatedAt          DATETIME2 NOT NULL CONSTRAINT DF_AdminUser_CreatedAt DEFAULT(SYSUTCDATETIME()),
    LastLoginAt        DATETIME2 NULL,
    CONSTRAINT UQ_AdminUser_Username UNIQUE (Username)
);
GO

-- ── BillingEvent: idempotent Stripe webhook ledger ──
IF OBJECT_ID('dbo.BillingEvent') IS NULL
CREATE TABLE dbo.BillingEvent (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    TenantId      INT          NULL,
    StripeEventId NVARCHAR(100) NOT NULL,
    Type          NVARCHAR(100) NULL,
    PayloadJson   NVARCHAR(MAX) NULL,
    ReceivedAt    DATETIME2    NOT NULL CONSTRAINT DF_Billing_Recv DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT UQ_Billing_StripeEventId UNIQUE (StripeEventId)
);
GO

-- ── TransactionAudit: Pillar 5 duplicate-transaction ledger ──
-- Byte-for-byte the table that EnsureCloneAuditTableAsync in
-- Startup/DatabaseBootstrapper.cs creates. Changing one means changing both,
-- exactly like the AdminUser block above.
--
-- It is provisioned HERE, up front, so the API's runtime login never needs
-- CREATE TABLE. The bootstrapper runs this DDL on every boot, but its
-- IF OBJECT_ID guard finds the table and the CREATE branch is never executed —
-- and SQL Server checks permissions on execution, not compilation, so a
-- db_datareader + db_datawriter login sails through the no-op.
--
-- Get this wrong and the failure is quiet: the bootstrapper catches the error,
-- the API still starts, /health/ready still passes, and only /admin is dead
-- (AdminPortalReady = false). See SERVER_SETUP.md gotcha 4 for why that login
-- is deliberately not db_owner.
IF OBJECT_ID('dbo.TransactionAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TransactionAudit (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        TenantId      INT NOT NULL,
        CompanyId     INT NOT NULL,
        ClientTxnId   NVARCHAR(128) NOT NULL,
        FirstDeviceId NVARCHAR(128) NOT NULL,
        LastDeviceId  NVARCHAR(128) NULL,
        SeenCount     INT NOT NULL DEFAULT(1),
        IsFlagged     BIT NOT NULL DEFAULT(0),
        FlagReason    NVARCHAR(64) NULL,
        FirstSeenUtc  DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME()),
        LastSeenUtc   DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX UX_TransactionAudit_Tenant_Txn
        ON dbo.TransactionAudit (TenantId, ClientTxnId);
END
GO
