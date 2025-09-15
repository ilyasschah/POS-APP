using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Sales.Api.DataBase;
using Sales.Api.Repository;
using Sales.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ===== CORS =====
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
        policy.AllowAnyOrigin() // TODO: restrict in prod
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// ===== DB =====
builder.Services.AddDbContext<AppDbContext>(op =>
    op.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ===== Repositories =====
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

// ===== Services =====
builder.Services.AddScoped<CountryService>();
builder.Services.AddScoped<CustomerService>();
builder.Services.AddScoped<CustomerDiscountService>();
builder.Services.AddScoped<CompanyService>();
builder.Services.AddScoped<StockControlService>();
builder.Services.AddScoped<LoyaltyCardService>();
builder.Services.AddScoped<UserService>();
builder.Services.AddScoped<PosOrderService>();
builder.Services.AddScoped<PosVoidService>();
builder.Services.AddScoped<PosOrderItemService>();
builder.Services.AddScoped<FloorPlanService>();
builder.Services.AddScoped<FloorPlanTableService>();
builder.Services.AddScoped<StartingCashService>();

// HttpClient for the Razor login page to call /api/Auth/Login
builder.Services.AddHttpClient();

builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));

// ===== Controllers + Razor Pages (to serve /Account/Login and wwwroot) =====
builder.Services.AddControllers();
builder.Services.AddRazorPages();

// === Authorization (add this so [Authorize] works later) ===
builder.Services.AddAuthorization();

// ===== Swagger =====
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// ===== JWT Auth (validation) =====
var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "dev-only-very-long-secret-change-me-please";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "Sales.Api";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "Sales.Clients";

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
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });

var app = builder.Build();

// ===== pipeline =====
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseCors("AllowFrontend");

app.UseStaticFiles();

app.UseAuthentication(); // before Authorization
app.UseAuthorization();

app.MapControllers();
app.MapRazorPages();

app.Run();
