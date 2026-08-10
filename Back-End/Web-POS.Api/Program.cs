using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
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
// One line per entry instead of the default's two, with a timestamp. The default
// console formatter puts the category on its own line, which doubles the height of
// every log and makes a real warning easy to scroll past.
builder.Logging.AddSimpleConsole(o =>
{
    o.SingleLine = true;
    o.TimestampFormat = "HH:mm:ss ";
});

// Reduce EF Core SQL noise
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.Warning);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Infrastructure", LogLevel.Warning);
// Kestrel's "Now listening on / Application started / Hosting environment /
// Content root path" — four lines saying what the startup banner says better, and
// it prints them before the banner so they read as the real output. Warnings and
// errors from the host still come through.
builder.Logging.AddFilter("Microsoft.Hosting.Lifetime", LogLevel.Warning);

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

// ================== DATA PROTECTION ==================
// The portal's session cookie AND every antiforgery token are encrypted with Data
// Protection keys, so where those keys live decides whether a deploy is invisible
// or hostile. Under IIS with no user profile loaded the framework falls back to an
// EPHEMERAL key ring — fresh keys on every app-pool recycle — which signs every
// operator out on each deploy and turns a login form that was already open into a
// 400 "antiforgery token invalid" that looks like a broken login page.
//
// SetApplicationName pins key isolation to a fixed string rather than the content
// root path, so the ring survives the site being redeployed to a different folder.
var dataProtection = builder.Services.AddDataProtection().SetApplicationName("Web-POS.Api");

// Optional. ⚠️ Point it OUTSIDE the deployed site root — the test deploy mirrors
// the publish output with `robocopy /MIR`, which deletes anything inside that it
// did not just copy, keys included.
var dataProtectionKeyPath = builder.Configuration["DataProtection:KeyPath"];
string dataProtectionKeyStore;

if (string.IsNullOrWhiteSpace(dataProtectionKeyPath))
{
    dataProtectionKeyStore =
        "<framework default — set DataProtection:KeyPath to keep sessions across deploys>";
}
else
{
    // Probed rather than trusted, and non-fatal either way: an unwritable key
    // folder must not take the whole POS API offline over a back-office cookie.
    try
    {
        Directory.CreateDirectory(dataProtectionKeyPath);
        var probe = Path.Combine(dataProtectionKeyPath, $".writeprobe-{Guid.NewGuid():N}.tmp");
        File.WriteAllText(probe, string.Empty);
        File.Delete(probe);

        dataProtection.PersistKeysToFileSystem(new DirectoryInfo(dataProtectionKeyPath));
        dataProtectionKeyStore = dataProtectionKeyPath;
    }
    catch (Exception ex)
    {
        dataProtectionKeyStore =
            $"<framework default — DataProtection:KeyPath '{dataProtectionKeyPath}' " +
            $"is not usable: {ex.Message}>";
    }
}

var app = builder.Build();

// ================== STARTUP ==================
var logger = app.Services.GetRequiredService<ILogger<Program>>();

// Findings, not diagnostics — these always print. In Development they also carry
// what WOULD have been fatal on a server, so problems surface on the dev box first.
Api.Startup.StartupDiagnostics.WriteWarnings(logger, configReport);

// The full masked configuration dump. OFF unless Startup:Diagnostics=true; the
// banner prints the hint automatically when something looks wrong.
Api.Startup.StartupDiagnostics.WriteIfEnabled(app, logger, dataProtectionKeyStore);

// NOTE: there is deliberately no second lease-key check here. StartupConfigurationValidator
// already reports a missing signing key (and the unwritable-content-root case this
// block never covered), and WriteWarnings above prints it — having both meant the
// same warning appeared twice on every single boot.

// Reachability checks + the idempotent, non-fatal schema/seed work both databases
// need before the first request. Returns what the startup banner reports.
var startupReport = await Api.Startup.DatabaseBootstrapper.RunAsync(
    app, logger, dataProtectionKeyStore);

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

// 🚨 "/admin" is what a human types, but NO page lives there — the portal's first
// screen is /admin/companies. Without this the request matches no endpoint at all,
// so it falls through to the global JWT FallbackPolicy and is answered by the
// BEARER handler, which challenges with a bare 401 instead of redirecting to the
// login page the way the cookie handler would. The result is "This page isn't
// working — HTTP ERROR 401" on the most obvious URL in the whole product.
app.MapGet("/admin", () => Results.Redirect("/admin/companies")).AllowAnonymous();

// Prints the banner (URLs + health) once Kestrel is listening, and in Development
// opens the portal in a browser. Both need the bound addresses, which do not exist
// until ApplicationStarted.
Api.Startup.StartupConsole.Register(app, startupReport);

app.Run();

/// <summary>
/// Top-level statements compile into an INTERNAL Program class, which
/// <c>WebApplicationFactory&lt;Program&gt;</c> cannot reach. Declaring the partial
/// makes it public so Web-POS.Api.Tests can boot the real pipeline — the only way
/// to test that an unauthenticated /admin request is actually redirected, rather
/// than testing a hand-rebuilt imitation of the pipeline.
/// </summary>
public partial class Program { }
