-- ============================================================================
-- Master SaaS control-plane database (ADR-002, Pillar 1)
-- Run once on the SQL Server. Kept SEPARATE from the tenant data ('web-pos')
-- so the per-company cascade delete can never touch billing/device records.
-- The API points at this via the "MasterConnection" connection string.
-- ============================================================================

IF DB_ID('web-pos-master') IS NULL
    CREATE DATABASE [web-pos-master];
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
