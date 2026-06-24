using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Diagnostics;
using System.Linq;
using System.Text;
using Api.Repository;
using Api.Services;
using Api.Attributes;
using Api.DataBase;

var builder = WebApplication.CreateBuilder(args);

// ================== LOGGING ==================
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Reduce EF Core SQL noise
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Infrastructure", LogLevel.Warning);

// ================== CONFIG ==================
var cs = builder.Configuration.GetConnectionString("DefaultConnection");

// ================== CORS ==================
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
        policy.AllowAnyOrigin() // TODO: restrict in prod
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// ================== DB CONTEXT ==================
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(cs, sql =>
    {
        sql.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(5),
            errorNumbersToAdd: null);
        sql.CommandTimeout(60);
    }));

// Master SaaS control-plane DB (Pillar 1) — a SEPARATE context/catalog from the
// tenant data. Configure its own catalog via the "MasterConnection" string;
// falls back to the default connection until you split it out. Connects lazily —
// nothing resolves it at startup, so an absent Master DB never blocks boot.
var masterCs = builder.Configuration.GetConnectionString("MasterConnection") ?? cs;
builder.Services.AddDbContext<Api.Master.MasterDbContext>(opt =>
    opt.UseSqlServer(masterCs, sql =>
    {
        sql.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(5),
            errorNumbersToAdd: null);
        sql.CommandTimeout(60);
    }));
builder.Services.AddScoped<Api.Master.Services.ITenantProvisioningService, Api.Master.Services.TenantProvisioningService>();
// Pillar 2 — offline subscription leases.
builder.Services.AddSingleton<Api.Master.Services.LeaseKeyService>();
builder.Services.AddScoped<Api.Master.Services.LeaseService>();
// Pillar 5 — clone / duplication audit.
builder.Services.AddScoped<Api.Master.Services.ICloneAuditService, Api.Master.Services.CloneAuditService>();

// ================== REPOSITORIES ==================
builder.Services.AddScoped<MenuRepository>();
builder.Services.AddScoped<BarcodeRepository>();
builder.Services.AddScoped<CurrencyRepository>();
builder.Services.AddScoped<FiscalItemRepository>();
builder.Services.AddScoped<ProductCommentRepository>();
builder.Services.AddScoped<ProductGroupRepository>();
builder.Services.AddScoped<ProductRepository>();
builder.Services.AddScoped<ProductTaxRepository>();
builder.Services.AddScoped<PromotionRepository>();
builder.Services.AddScoped<PromotionItemRepository>();
builder.Services.AddScoped<SecurityKeyRepository>();
builder.Services.AddScoped<TaxRepository>();
builder.Services.AddScoped<VoidReasonRepository>();
builder.Services.AddScoped<CountryRepository>();
builder.Services.AddScoped<CustomerRepository>();
builder.Services.AddScoped<CustomerDiscountRepository>();
builder.Services.AddScoped<CompanyRepository>();
builder.Services.AddScoped<StockControlRepository>();
builder.Services.AddScoped<LoyaltyCardRepository>();
builder.Services.AddScoped<UserRepository>();
builder.Services.AddScoped<PosOrderRepository>();
builder.Services.AddScoped<PosVoidRepository>();
builder.Services.AddScoped<PosOrderItemRepository>();
builder.Services.AddScoped<FloorPlanRepository>();
builder.Services.AddScoped<FloorPlanTableRepository>();
builder.Services.AddScoped<StartingCashRepository>();
builder.Services.AddScoped<WarehouseRepository>();
builder.Services.AddScoped<StockRepository>();
builder.Services.AddScoped<ZReportRepository>();
builder.Services.AddScoped<PaymentTypeRepository>();
builder.Services.AddScoped<PaymentRepository>();
builder.Services.AddScoped<DocumentRepository>();
builder.Services.AddScoped<DocumentCategoryRepository>();
builder.Services.AddScoped<DocumentTypeRepository>();
builder.Services.AddScoped<DocumentItemRepository>();
builder.Services.AddScoped<DocumentItemTaxRepository>();
builder.Services.AddScoped<DocumentItemExpirationDateRepository>();
builder.Services.AddScoped<DocumentsCounterRepository>();
builder.Services.AddScoped<ApplicationPropertyRepository>();
builder.Services.AddScoped<MigrationRepository>();
builder.Services.AddScoped<PosPrinterSelectionRepository>();
builder.Services.AddScoped<PosPrinterSelectionSettingsRepository>();
builder.Services.AddScoped<PosPrinterSettingsRepository>();
builder.Services.AddScoped<TemplateRepository>();
builder.Services.AddScoped<BookingRepository>();
builder.Services.AddScoped<UserDevicePinRepository>();
builder.Services.AddScoped<ShiftRepository>();
builder.Services.AddScoped<TimeClockRepository>();

// ================== SERVICES ==================
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<BarcodeService>();
builder.Services.AddScoped<CurrencyService>();
builder.Services.AddScoped<FiscalItemService>();
builder.Services.AddScoped<ProductCommentService>();
builder.Services.AddScoped<ProductGroupService>();
builder.Services.AddScoped<ProductService>();
builder.Services.AddScoped<ProductTaxService>();
builder.Services.AddScoped<PromotionService>();
builder.Services.AddScoped<PromotionItemService>();
builder.Services.AddScoped<SecurityKeyService>();
builder.Services.AddScoped<TaxService>();
builder.Services.AddScoped<VoidReasonService>();
builder.Services.AddScoped<CustomerService>();
builder.Services.AddScoped<CustomerDiscountService>();
builder.Services.AddScoped<CompanyService>();
builder.Services.AddScoped<StockControlService>();
builder.Services.AddScoped<LoyaltyCardService>();
builder.Services.AddScoped<UserService>();
builder.Services.AddScoped<UserDevicePinService>();
builder.Services.AddScoped<PosOrderService>();
builder.Services.AddScoped<PosVoidService>();
builder.Services.AddScoped<PosOrderItemService>();
builder.Services.AddScoped<FloorPlanService>();
builder.Services.AddScoped<FloorPlanTableService>();
builder.Services.AddScoped<StartingCashService>();
builder.Services.AddScoped<StockService>();
builder.Services.AddScoped<WarehouseService>();
builder.Services.AddScoped<ZReportService>();
builder.Services.AddScoped<PaymentTypeService>();
builder.Services.AddScoped<PaymentService>();
builder.Services.AddScoped<DocumentService>();
builder.Services.AddScoped<DocumentTypeService>();
builder.Services.AddScoped<DocumentItemService>();
builder.Services.AddScoped<DocumentItemTaxService>();
builder.Services.AddScoped<DocumentItemExpirationDateService>();
builder.Services.AddScoped<DocumentsCounterService>();
builder.Services.AddScoped<ApplicationPropertyService>();
builder.Services.AddScoped<MigrationService>();
builder.Services.AddScoped<PosPrinterSelectionService>();
builder.Services.AddScoped<PosPrinterSettingsService>();
builder.Services.AddScoped<PosPrinterSelectionSettingsService>();
builder.Services.AddScoped<TemplateService>();
builder.Services.AddScoped<PosOrderCheckoutService>();
builder.Services.AddScoped<PosOrderVoidService>();
builder.Services.AddScoped<BookingService>();

builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));

// ================== MVC / SWAGGER ==================
builder.Services.AddControllers();
// Admin SaaS portal (server-rendered Razor Pages under /admin).
builder.Services.AddRazorPages();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.DocInclusionPredicate((docName, apiDesc) =>
    {
        var actionDescriptor =
            apiDesc.ActionDescriptor as
            Microsoft.AspNetCore.Mvc.Controllers.ControllerActionDescriptor;

        if (actionDescriptor == null)
            return false;

        var hasAttribute =
            actionDescriptor.ControllerTypeInfo
            .GetCustomAttributes(typeof(SwaggerVisibleAttribute), true)
            .Any();

        return hasAttribute;
    });
});

// ================== AUTH ==================
builder.Services.AddAuthorization();

var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "dev-only-very-long-secret-change-me-please";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "Products.Api";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "Products.Clients";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.RequireHttpsMetadata = true;
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtSecret)),
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });

var app = builder.Build();

// ================== STARTUP LOGS ==================
var logger = app.Services.GetRequiredService<ILogger<Program>>();

logger.LogInformation("========================================");
logger.LogInformation("Web POS - Api starting");
logger.LogInformation("Environment: {env}", app.Environment.EnvironmentName);
logger.LogInformation("Content root: {root}", app.Environment.ContentRootPath);
logger.LogInformation("========================================");

// Safe DB health check (no SQL spam)
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var canConnect = db.Database.CanConnect();
        logger.LogInformation("Database status: {status}", canConnect ? "OK" : "FAILED");

        // Ensure the global reference tables exist (re-seeds if a wipe emptied
        // them) so the app can never start up without the static data it needs.
        if (canConnect)
        {
            await Api.Services.GlobalDefaultsSeeder.SeedAsync(db);
            logger.LogInformation("Global reference data verified/seeded.");

            // Backfill any security keys added in app updates onto existing
            // companies (e.g. CashMovement / ShiftManagement). Idempotent —
            // only adds missing keys, never touches admin-customised levels.
            await Api.Services.CompanyDefaultsSeeder.BackfillSecurityKeysAsync(db);
            logger.LogInformation("Security keys verified/backfilled for existing companies.");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database check / global seed failed");
    }
}

// Pillar 5 — ensure the clone-audit ledger exists in the Master DB. The control
// plane has no EF migrations (it's provisioned from docs/sql/master-db-schema.sql),
// so this self-heals the one additive table. Idempotent + non-fatal: an absent or
// unreachable Master DB never blocks boot.
using (var scope = app.Services.CreateScope())
{
    try
    {
        var master = scope.ServiceProvider.GetRequiredService<Api.Master.MasterDbContext>();
        if (master.Database.CanConnect())
        {
            await master.Database.ExecuteSqlRawAsync(@"
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
                END");
            logger.LogInformation("Pillar 5 clone-audit table verified.");
        }
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Clone-audit table ensure skipped (Master DB unavailable?)");
    }
}

// ================== PIPELINE ==================

// Map business-rule exceptions to the { success, message } error contract
// (400/404/403) instead of raw 500s. Registered first so it wraps all controllers.
app.UseMiddleware<Api.Middleware.ExceptionHandlingMiddleware>();

app.UseSwagger();
app.UseSwaggerUI(c => {
    c.SwaggerEndpoint("./v1/swagger.json", "My API V1");
    c.RoutePrefix = "swagger";
});

//app.UseHttpsRedirection();
app.UseCors("AllowFrontend");
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();
// Shared-secret gate for the /admin SaaS portal (no login form).
app.UseMiddleware<Api.Middleware.AdminPortalGate>();
app.MapControllers();
app.MapRazorPages();

// Hitting the site root lands you on the admin portal.
app.MapGet("/", () => Results.Redirect("/admin/companies"));

// On startup, open the admin portal in the default browser already authorised
// with the access key (sets the cookie) — so there's no manual key step.
app.Lifetime.ApplicationStarted.Register(() =>
{
    try
    {
        var key = app.Configuration["AdminPortal:AccessKey"] ?? "";
        var addresses = app.Services.GetService<IServer>()?
            .Features.Get<IServerAddressesFeature>()?.Addresses;
        var baseUrl = (addresses != null
            ? addresses.FirstOrDefault(a => a.StartsWith("http://")) ?? addresses.FirstOrDefault()
            : null) ?? "http://localhost:5002";
        baseUrl = baseUrl.Replace("0.0.0.0", "localhost").Replace("[::]", "localhost").TrimEnd('/');
        var url = $"{baseUrl}/admin/companies?key={Uri.EscapeDataString(key)}";
        Process.Start(new ProcessStartInfo { FileName = url, UseShellExecute = true });
    }
    catch { /* opening a browser is best-effort — never block startup */ }
});

app.Run();
