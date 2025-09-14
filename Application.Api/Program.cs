using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Repository;
using Products.Api.Services;
var builder = WebApplication.CreateBuilder(args);
// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend",
        policy =>
        {
            policy
                .AllowAnyOrigin() // for testing; later restrict to specific origins
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
});

// Add services to the container.
builder.Services.AddDbContext<AppDbContext>(op => op.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

//Repo
builder.Services.AddScoped<ApplicationPropertyRepository>();
builder.Services.AddScoped<MigrationRepository>();
builder.Services.AddScoped<PosPrinterSelectionRepository>();
builder.Services.AddScoped<PosPrinterSelectionSettingsRepository>();
builder.Services.AddScoped<PosPrinterSettingsRepository>();
builder.Services.AddScoped<TemplateRepository>();

//Services
builder.Services.AddScoped<ApplicationPropertyService>();
builder.Services.AddScoped<MigrationService>();
builder.Services.AddScoped<PosPrinterSelectionService>();
builder.Services.AddScoped<PosPrinterSettingsService>();
builder.Services.AddScoped<PosPrinterSelectionSettingsService>();
builder.Services.AddScoped<TemplateService>();

builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowFrontend");
app.UseAuthorization();
app.MapControllers();
app.Run();
