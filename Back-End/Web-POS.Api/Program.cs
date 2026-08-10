using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
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
using Api.Configuration;
using Api.DataBase;
using FluentValidation;
using MediatR;

var builder = WebApplication.CreateBuilder(args);

// ================== LOGGING ==================
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Reduce EF Core SQL noise
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Infrastructure", LogLevel.Warning);

// ================== CONFIG ==================
// Machine-local overrides. Git-ignored, and excluded from publish output via the
// csproj, so it can never ship to a server.
//
// It must sit AFTER the appsettings*.json files but BEFORE the environment
// variables, so that a server's env vars still win. Note that the obvious
// `builder.Configuration.AddJsonFile(...)` APPENDS to the end of the chain, which
// would let this file silently override an env var — the exact opposite of what
// is wanted. So insert it at the right position instead.
var localSettings = new Microsoft.Extensions.Configuration.Json.JsonConfigurationSource
{
    Path = "appsettings.Local.json",
    Optional = true,
    ReloadOnChange = true,
};

var envVarSourceIndex = builder.Configuration.Sources
    .ToList()
    .FindIndex(s =>
        s is Microsoft.Extensions.Configuration.EnvironmentVariables
             .EnvironmentVariablesConfigurationSource { Prefix: null or "" });

if (envVarSourceIndex >= 0)
    builder.Configuration.Sources.Insert(envVarSourceIndex, localSettings);
else
    builder.Configuration.Sources.Add(localSettings);

var cs = builder.Configuration.GetConnectionString("DefaultConnection");

// ================== CORS ==================
// Configurable rather than hardcoded. Note the POS clients are native Windows /
// Android apps, which are not subject to CORS at all, and the admin portal is
// same-origin — so the permissive default is far less exposed than it looks. Set
// Cors:AllowedOrigins to lock it down for browser callers.
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy.WithOrigins(allowedOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
        else
        {
            // Unchanged historical behaviour when no origins are configured.
            policy.AllowAnyOrigin()
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
    });
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
// Admin portal accounts (also in the Master DB — they administer every company,
// so they must sit outside the per-company cascade delete).
builder.Services.AddScoped<Api.Admin.AdminUserService>();

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
builder.Services.AddScoped<PosPrinterSettingsService>();
builder.Services.AddScoped<TemplateService>();
builder.Services.AddScoped<PosOrderCheckoutService>();
builder.Services.AddScoped<PosOrderVoidService>();
builder.Services.AddScoped<BookingService>();

builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));

// The ~150 AbstractValidator classes in this assembly were previously never
// registered or invoked, so nothing validated. Register them and run them through
// a pipeline behaviour. NOTE it starts in OBSERVE mode (logs violations, does not
// reject) — see ValidationBehavior for the rollout plan and the Validation:Enforce
// switch that turns on real 400s.
builder.Services.AddValidatorsFromAssembly(typeof(Program).Assembly);
builder.Services.AddTransient(
    typeof(IPipelineBehavior<,>), typeof(Api.Behaviors.ValidationBehavior<,>));

// ================== MVC / SWAGGER ==================
builder.Services.AddControllers();
// Admin SaaS portal (server-rendered Razor Pages under /admin). It authenticates
// with its own COOKIE scheme and per-user accounts (Api.Admin.AdminPortalAuth) —
// not the JWT the POS clients carry, and no longer the shared ?key= secret.
builder.Services.AddRazorPages(options =>
{
    // Attaching an explicit policy is doing two jobs. It gates the portal on a
    // signed-in admin, AND it gives these pages authorization metadata of their
    // own — which is what excludes them from the global JWT FallbackPolicy below.
    // The fallback only applies to endpoints that declare nothing.
    options.Conventions.AuthorizeFolder("/Admin", Api.Admin.AdminPortalAuth.PolicyName);

    // ⚠️ The two pages that MUST stay reachable while signed out. Without these the
    // login form is itself behind the login and the portal is unreachable from a
    // browser with no cookie — i.e. every browser, the first time.
    options.Conventions.AllowAnonymousToPage(Api.Admin.AdminPortalAuth.LoginPage);
    options.Conventions.AllowAnonymousToPage(Api.Admin.AdminPortalAuth.LogoutPage);
});
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
// "ManagerOnly" = accounts whose token carries role "Admin" (accessLevel 0).
// Apply with [Authorize(Policy = "ManagerOnly")] on manager-only endpoints.
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("ManagerOnly", policy => policy.RequireRole("Admin"));

    // The admin portal's own policy. ⚠️ AddAuthenticationSchemes is load-bearing:
    // the API's DEFAULT scheme is JwtBearer, so a policy that does not name the
    // cookie scheme authenticates a browser request against the bearer handler,
    // never sees the portal cookie, and challenges an already-signed-in operator
    // in a loop.
    options.AddPolicy(Api.Admin.AdminPortalAuth.PolicyName, policy => policy
        .AddAuthenticationSchemes(Api.Admin.AdminPortalAuth.Scheme)
        .RequireAuthenticatedUser());

    // Fail-closed: every endpoint requires an authenticated user UNLESS it opts out
    // with [AllowAnonymous]. This is the safety net — a newly-added controller is
    // protected by default instead of silently shipping open (which is how ~45
    // controllers ended up unauthenticated). The deliberate anonymous surface is:
    // POST /api/Auth/Login, GET /api/Master/LeasePublicKey, GET /api/Master/Lease,
    // the admin portal's login/logout pages, and the "/" redirect. The rest of the
    // /Admin folder carries the AdminPortal policy above instead.
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

// ================== CONFIGURATION VALIDATION ==================
// Fail-closed on every required setting BEFORE anything is wired up. Outside
// Development a missing/short/placeholder Jwt:Secret, an unparseable lease key or
// an absent connection string aborts startup rather than surfacing later as a
// forged "Admin" token or a 500 on the first login. In Development the same
// findings are downgraded to warnings so a fresh clone runs with no setup.
var configReport = StartupConfigurationValidator.Validate(
    builder.Configuration, builder.Environment);

if (configReport.HasErrors)
{
    // Written to stderr as well as thrown: the host logger does not exist yet, and
    // a bare stack trace in the Windows Event Log is far less useful than this list.
    var fatal = StartupConfigurationValidator.FormatFatalMessage(configReport, builder.Environment);
    Console.Error.WriteLine(fatal);
    throw new InvalidOperationException(fatal);
}

// Resolved through JwtSettings so issuance (TokenService) and validation (below)
// can never disagree — see the note in that class about the empty-string trap.
var jwtSecret = JwtSettings.ResolveSecret(builder.Configuration);
var jwtIssuer = JwtSettings.ResolveIssuer(builder.Configuration);
var jwtAudience = JwtSettings.ResolveAudience(builder.Configuration);

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
    })
    // The admin portal's session cookie. A second, NON-default scheme: the POS API
    // keeps authenticating with JwtBearer, and only the /Admin pages name this one.
    .AddCookie(Api.Admin.AdminPortalAuth.Scheme, opt =>
    {
        opt.Cookie.Name = Api.Admin.AdminPortalAuth.CookieName;
        opt.Cookie.HttpOnly = true;
        opt.Cookie.SameSite = SameSiteMode.Lax;
        // SameAsRequest, not Always: the portal is served over plain http on the
        // LAN (the dev box binds http://…:5002), and Always would issue a cookie
        // the browser refuses to send back — an unfixable login loop.
        opt.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;

        opt.LoginPath = Api.Admin.AdminPortalAuth.LoginPath;
        opt.LogoutPath = Api.Admin.AdminPortalAuth.LogoutPath;
        opt.AccessDeniedPath = Api.Admin.AdminPortalAuth.LoginPath;
        opt.ReturnUrlParameter = "returnUrl";

        opt.ExpireTimeSpan = Api.Admin.AdminPortalAuth.SessionLifetime;
        opt.SlidingExpiration = true;
    });

var app = builder.Build();

// ================== STARTUP LOGS ==================
var logger = app.Services.GetRequiredService<ILogger<Program>>();

logger.LogInformation("========================================");
logger.LogInformation("Web POS - Api starting");
logger.LogInformation("Environment: {env}", app.Environment.EnvironmentName);
logger.LogInformation("Content root: {root}", app.Environment.ContentRootPath);
logger.LogInformation("========================================");

// ================== CONFIG DIAGNOSTICS ==================
// Answers "is the server actually reading my environment variables?" from the
// first lines of the log. Secrets are masked to first/last 4 chars — never log
// a whole secret. Each value also reports WHICH provider won, so an env var
// that silently lost to appsettings.json (or was never seen) is obvious.
static string MaskSecret(string? value)
{
    if (string.IsNullOrEmpty(value)) return "<EMPTY / NOT SET>";
    if (value.Length <= 8) return $"**** (len={value.Length} — suspiciously short)";
    return $"{value[..4]}...{value[^4..]} (len={value.Length})";
}

static string MaskConnectionString(string? cs) =>
    string.IsNullOrEmpty(cs)
        ? "<EMPTY / NOT SET>"
        : System.Text.RegularExpressions.Regex.Replace(
            cs, @"(Password\s*=\s*)[^;]*", "$1****",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

// Providers are applied in order and the LAST one holding a key wins, so walk
// them backwards and report the first hit — that is the effective source.
static string SourceOf(IConfiguration config, string key)
{
    if (config is not IConfigurationRoot root) return "unknown";
    foreach (var provider in root.Providers.Reverse())
    {
        if (provider.TryGet(key, out _))
            return provider.ToString() ?? provider.GetType().Name;
    }
    return "<no provider supplied this key>";
}

// Warnings collected before the logger existed — surface them now, loudly. In
// Development this also carries the findings that WOULD have been fatal in
// Production, so problems are visible on the dev box before they reach a server.
foreach (var warning in configReport.Warnings)
    logger.LogWarning("CONFIG: {warning}", warning);

logger.LogInformation("--- Configuration providers (later overrides earlier) ---");
if (app.Configuration is IConfigurationRoot configRoot)
{
    foreach (var provider in configRoot.Providers)
        logger.LogInformation("    {provider}", provider.ToString());
}

logger.LogInformation("--- Resolved configuration ---");
logger.LogInformation("ASPNETCORE_ENVIRONMENT  : {value}",
    Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? "<not set> -> defaults to Production");
logger.LogInformation("Jwt:Secret              : {value}  [source: {source}]",
    MaskSecret(app.Configuration["Jwt:Secret"]), SourceOf(app.Configuration, "Jwt:Secret"));
logger.LogInformation("Jwt:Issuer              : {value}  [source: {source}]",
    app.Configuration["Jwt:Issuer"] ?? "<not set>", SourceOf(app.Configuration, "Jwt:Issuer"));
logger.LogInformation("Jwt:Audience            : {value}  [source: {source}]",
    app.Configuration["Jwt:Audience"] ?? "<not set>", SourceOf(app.Configuration, "Jwt:Audience"));
logger.LogInformation("Lease:PrivateKeyPem     : {value}  [source: {source}]",
    string.IsNullOrWhiteSpace(app.Configuration["Lease:PrivateKeyPem"])
        ? "<not set> -> falling back to lease_signing_key.pem on disk"
        : $"<supplied, {app.Configuration["Lease:PrivateKeyPem"]!.Length} chars>",
    SourceOf(app.Configuration, "Lease:PrivateKeyPem"));
logger.LogInformation("ConnectionStrings:Default: {value}  [source: {source}]",
    MaskConnectionString(app.Configuration.GetConnectionString("DefaultConnection")),
    SourceOf(app.Configuration, "ConnectionStrings:DefaultConnection"));
logger.LogInformation("ConnectionStrings:Master : {value}  [source: {source}]",
    MaskConnectionString(app.Configuration.GetConnectionString("MasterConnection")),
    SourceOf(app.Configuration, "ConnectionStrings:MasterConnection"));

// Loud, actionable warning for the failure that actually bites on a new box.
var leaseKeyOnDisk = Path.Combine(app.Environment.ContentRootPath, "lease_signing_key.pem");
if (string.IsNullOrWhiteSpace(app.Configuration["Lease:PrivateKeyPem"]) &&
    !File.Exists(leaseKeyOnDisk))
{
    logger.LogWarning(
        "No lease signing key configured and none on disk at {path} — a NEW keypair " +
        "will be generated. Leases/public keys issued by any other server instance " +
        "will not validate against it.", leaseKeyOnDisk);
}
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

            // Admin portal accounts. Same reasoning and same non-fatal contract as
            // the block above: no EF migrations on this database, so the table is
            // self-healed here for any machine that has not run
            // docs/sql/master-db-schema.sql.
            //
            // ⚠️ Both of these must complete BEFORE the pipeline starts serving.
            // From the moment the API loads, EF emits every AdminUser column in
            // every query for that entity — a missing table is an immediate
            // "Invalid object name", not a deferred one.
            await Api.Admin.AdminUserSeeder.EnsureTableAsync(master);
            await Api.Admin.AdminUserSeeder.SeedFirstAdminAsync(master, logger);
            logger.LogInformation("Admin portal account table verified.");
        }
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Master DB table ensure skipped (Master DB unavailable?)");
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

// Hardening headers for every /admin response. ⚠️ BEFORE UseAuthorization, not
// after (where the old AdminPortalGate sat): an unauthenticated request is
// short-circuited by the authorization middleware with a 302 to the login page,
// so anything registered after it never runs for the very responses that most
// need no-store.
app.UseMiddleware<Api.Middleware.AdminPortalSecurityHeaders>();

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapRazorPages();

// Hitting the site root lands you on the admin portal. Anonymous — the portal
// pages carry their own authorization policy, so an unauthenticated visitor is
// redirected on to the login page from there; this is just a redirect.
app.MapGet("/", () => Results.Redirect("/admin/companies")).AllowAnonymous();

// On startup, open the admin portal in the default browser. It lands on the login
// page when there is no session — there is no key to pre-authorise any more.
//
// Development only. Spawning a browser is a convenience for whoever pressed F5;
// on a server (or inside a test host) there is no desktop to open it on, and the
// attempt is pure noise. Both launch profiles set ASPNETCORE_ENVIRONMENT=Development,
// so the F5 behaviour is unchanged.
if (app.Environment.IsDevelopment())
{
    app.Lifetime.ApplicationStarted.Register(() =>
    {
        try
        {
            var addresses = app.Services.GetService<IServer>()?
                .Features.Get<IServerAddressesFeature>()?.Addresses;
            var baseUrl = (addresses != null
                ? addresses.FirstOrDefault(a => a.StartsWith("http://")) ?? addresses.FirstOrDefault()
                : null) ?? "http://localhost:5002";
            baseUrl = baseUrl.Replace("0.0.0.0", "localhost").Replace("[::]", "localhost").TrimEnd('/');
            Process.Start(new ProcessStartInfo
            {
                FileName = $"{baseUrl}/admin/companies",
                UseShellExecute = true,
            });
        }
        catch { /* opening a browser is best-effort — never block startup */ }
    });
}

app.Run();

/// <summary>
/// Top-level statements compile into an INTERNAL Program class, which
/// <c>WebApplicationFactory&lt;Program&gt;</c> cannot reach. Declaring the partial
/// makes it public so Web-POS.Api.Tests can boot the real pipeline — the only way
/// to test that an unauthenticated /admin request is actually redirected, rather
/// than testing a hand-rebuilt imitation of the pipeline.
/// </summary>
public partial class Program { }
