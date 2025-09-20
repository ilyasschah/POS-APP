using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
namespace Products.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<Currency> Currencies { get; set; }
        public DbSet<ProductGroup> ProductGroups { get; set; }
        public DbSet<Product> Products { get; set; } 
        public DbSet<Barcode> Barcodes { get; set; }
        public DbSet<SecurityKey> SecurityKeys { get; set; }
        public DbSet<ProductComment> ProductComments { get; set; }
        public DbSet<Tax> Taxes { get; set; }
        public DbSet<ProductTax> ProductsTaxes { get; set; }
        public DbSet<VoidReason> VoidReasons { get; internal set; }
        public DbSet<FiscalItem> FiscalItems { get; internal set; }
        public DbSet<Promotion> Promotions { get; internal set; }
        public DbSet<PromotionItem> PromotionItems { get; internal set; }
        public DbSet<Customer> Customers { get; set; }
        public DbSet<Country> Countries { get; set; }
        public DbSet<CustomerDiscount> CustomerDiscounts { get; set; }
        public DbSet<Company> Companies { get; set; }
        public DbSet<StockControl> StockControls { get; set; }
        public DbSet<LoyaltyCard> LoyaltyCards { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<PosOrder> PosOrders { get; set; }
        public DbSet<PosVoid> PosVoids { get; set; }
        public DbSet<PosOrderItem> PosOrderItems { get; set; }
        public DbSet<FloorPlan> FloorPlans { get; set; }
        public DbSet<FloorPlanTable> FloorPlanTables { get; set; }
        public DbSet<StartingCash> StartingCashes { get; set; }
        public DbSet<Warehouse> Warehouses { get; set; }
        public DbSet<Stock> Stocks { get; set; }
        public DbSet<ApplicationProperty> ApplicationProperties { get; set; }
        public DbSet<Migration> Migrations { get; set; }
        public DbSet<PosPrinterSelection> PosPrinterSelections { get; set; }
        public DbSet<PosPrinterSettings> PosPrinterSettings { get; set; }
        public DbSet<PosPrinterSelectionSettings> PosPrinterSelectionSettings { get; set; }
        public DbSet<Template> Templates { get; set; }
        public DbSet<ZReport> ZReports { get; set; }
        public DbSet<PaymentType> PaymentTypes { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<Document> Documents { get; set; }
        public DbSet<DocumentCategory> DocumentCategories { get; set; }
        public DbSet<DocumentType> DocumentTypes { get; set; }
        public DbSet<DocumentItem> DocumentItems { get; set; }
        public DbSet<DocumentItemTax> DocumentItemTaxes { get; set; }
        public DbSet<DocumentItemExpirationDate> DocumentItemExpirationDates { get; set; }
        public DbSet<DocumentsCounter> DocumentsCounter { get; set; }
    }
}
