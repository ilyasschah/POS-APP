using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
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
builder.Services.AddScoped<CountryService>();
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
builder.Services.AddScoped<DocumentCategoryService>();
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
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database check failed");
    }
}

// ================== PIPELINE ==================

app.UseSwagger();
app.UseSwaggerUI(c => {
    c.SwaggerEndpoint("./v1/swagger.json", "My API V1");
    c.RoutePrefix = "swagger";
});

//app.UseHttpsRedirection();
app.UseCors("AllowFrontend");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
