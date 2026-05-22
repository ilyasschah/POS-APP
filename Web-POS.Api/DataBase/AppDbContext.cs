using Microsoft.EntityFrameworkCore;
using System.Reflection.Emit;
using Api.Domain;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using System.Linq;
using System;
namespace Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<Currency> Currencies { get; set; }
        public DbSet<UserDevicePin> UserDevicePins { get; set; }
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
        public DbSet<PosOrderItemTax> PosOrderItemTaxes { get; set; }
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
        public DbSet<ZReportPaymentSummary> ZReportPaymentSummaries { get; internal set; }
        public DbSet<Booking> Bookings { get; set; }
        public DbSet<DashboardSalesDataView> DashboardSalesDataViews { get; set; }
        public DbSet<SalesByProductRow> SalesByProductRows { get; set; }
        public DbSet<SalesByTaxRow> SalesByTaxRows { get; set; }
        public DbSet<SalesItemListRow> SalesItemListRows { get; set; }
        public DbSet<SalesByPaymentTypeRow> SalesByPaymentTypeRows { get; set; }
        public DbSet<RefundItemListRow> RefundItemListRows { get; set; }
        public DbSet<InvoiceListRow> InvoiceListRows { get; set; }
        public DbSet<DailySalesRow> DailySalesRows { get; set; }
        public DbSet<HourlySalesRow> HourlySalesRows { get; set; }
        public DbSet<HourlySalesByGroupRow> HourlySalesByGroupRows { get; set; }
        public DbSet<SalesByTableRow> SalesByTableRows { get; set; }
        public DbSet<ProfitRow> ProfitRows { get; set; }
        public DbSet<UnpaidSalesRow> UnpaidSalesRows { get; set; }
        public DbSet<DiscountsGrantedRow> DiscountsGrantedRows { get; set; }
        public DbSet<ItemsDiscountsRow> ItemsDiscountsRows { get; set; }
        public DbSet<StockMovementRow> StockMovementRows { get; set; }
        public DbSet<PurchaseByProductRow> PurchaseByProductRows { get; set; }
        public DbSet<UnpaidPurchaseRow> UnpaidPurchaseRows { get; set; }
        public DbSet<PurchaseDiscountsRow> PurchaseDiscountsRows { get; set; }
        public DbSet<PurchaseItemsDiscountsRow> PurchaseItemsDiscountsRows { get; set; }
        public DbSet<PurchaseInvoiceListRow> PurchaseInvoiceListRows { get; set; }
        public DbSet<PurchaseByTaxRow> PurchaseByTaxRows { get; set; }
        public DbSet<PurchaseExpirationDateRow> PurchaseExpirationDateRows { get; set; }
        public DbSet<StockReturnByProductRow> StockReturnByProductRows { get; set; }
        public DbSet<LossAndDamageByProductRow> LossAndDamageByProductRows { get; set; }
        public DbSet<TransactionHistoryRow> TransactionHistoryRows { get; set; }

        protected override void ConfigureConventions(ModelConfigurationBuilder cfg)
        {
            cfg.Properties<decimal>().HavePrecision(18, 2);
        }
        protected override void OnModelCreating(ModelBuilder b)
        {

            base.OnModelCreating(b);

            b.Entity<DashboardSalesDataView>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_DashboardSalesData");
            });

            b.Entity<SalesByProductRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_SalesByProduct");
            });

            b.Entity<SalesByTaxRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_SalesByTax");
            });

            b.Entity<SalesItemListRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_SalesItemList");
            });

            b.Entity<SalesByPaymentTypeRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_SalesByPaymentType");
            });

            b.Entity<RefundItemListRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_RefundItemList");
            });

            b.Entity<InvoiceListRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_InvoiceList");
            });

            b.Entity<DailySalesRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_DailySalesRow");
            });

            b.Entity<HourlySalesRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_HourlySalesRow");
            });

            b.Entity<HourlySalesByGroupRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_HourlySalesByGroupRow");
            });

            b.Entity<SalesByTableRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_SalesByTableRow");
            });

            b.Entity<ProfitRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_ProfitRow");
            });

            b.Entity<UnpaidSalesRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_UnpaidSalesRow");
            });

            b.Entity<DiscountsGrantedRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_DiscountsGranted");
            });

            b.Entity<ItemsDiscountsRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_ItemsDiscounts");
                entity.Property(x => x.TotalDiscount).HasPrecision(18, 2);
            });

            b.Entity<StockMovementRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_StockMovement");
                entity.Property(x => x.Quantity).HasPrecision(18, 4);
            });

            b.Entity<PurchaseByProductRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseByProduct");
            });

            b.Entity<UnpaidPurchaseRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_UnpaidPurchaseRow");
            });

            b.Entity<PurchaseDiscountsRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseDiscounts");
            });

            b.Entity<PurchaseItemsDiscountsRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseItemsDiscounts");
                entity.Property(x => x.Quantity).HasPrecision(18, 4);
                entity.Property(x => x.DiscountValue).HasPrecision(18, 2);
            });

            b.Entity<PurchaseInvoiceListRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseInvoiceList");
            });

            b.Entity<PurchaseByTaxRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseByTax");
            });

            b.Entity<PurchaseExpirationDateRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_PurchaseExpirationDate");
                entity.Property(x => x.Quantity).HasPrecision(18, 4);
            });

            b.Entity<StockReturnByProductRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_StockReturnByProduct");
                entity.Property(x => x.Quantity).HasPrecision(18, 4);
            });

            b.Entity<LossAndDamageByProductRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_LossAndDamageByProduct");
                entity.Property(x => x.Quantity).HasPrecision(18, 4);
            });

            b.Entity<TransactionHistoryRow>(entity =>
            {
                entity.HasNoKey();
                entity.ToView("vw_TransactionHistory");
                entity.Property(x => x.Credit).HasPrecision(18, 2);
                entity.Property(x => x.Debit).HasPrecision(18, 2);
            });

            b.Entity<Document>(e =>
            {
                e.ToTable(table => table.HasTrigger("Document_Insert_Trigger"));
                e.Property(x => x.Discount).HasPrecision(18, 2);
                e.Property(x => x.Total).HasPrecision(18, 2);
            });

            b.Entity<DocumentItem>(e =>
            {
                e.ToTable(tb => tb.HasTrigger("DocumentItem_Insert_Trigger"));
                e.Property(x => x.Discount).HasPrecision(18, 2);
                e.Property(x => x.ExpectedQuantity).HasPrecision(18, 4);
                e.Property(x => x.Price).HasPrecision(18, 2);
                e.Property(x => x.PriceAfterDiscount).HasPrecision(18, 2);
                e.Property(x => x.PriceBeforeTax).HasPrecision(18, 2);
                e.Property(x => x.PriceBeforeTaxAfterDiscount).HasPrecision(18, 2);
                e.Property(x => x.ProductCost).HasPrecision(18, 2);
                e.Property(x => x.Quantity).HasPrecision(18, 4);
                e.Property(x => x.Total).HasPrecision(18, 2);
                e.Property(x => x.TotalAfterDocumentDiscount).HasPrecision(18, 2);
            });

            b.Entity<DocumentItemTax>(e => 
            {
                e.Property(x => x.Amount).HasPrecision(18, 2);
                e.HasKey(dit => new { dit.DocumentItemId, dit.TaxId });
            });
            b.Entity<FloorPlanTable>()
                .ToTable("FloorPlanTable", tb => tb.HasTrigger("SomeTrigger"));

            b.Entity<Booking>(e =>
            {
                e.ToTable("Booking", tb => tb.HasTrigger("SomeTrigger"));

                var intListComparer = new ValueComparer<List<int>>(
                    (c1, c2) => c1.SequenceEqual(c2),
                    c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
                    c => c.ToList());

                e.Property(x => x.TableIds)
                    .HasConversion(
                        v => System.Text.Json.JsonSerializer.Serialize(v, (System.Text.Json.JsonSerializerOptions?)null),
                        v => string.IsNullOrEmpty(v)
                            ? new List<int>()
                            : System.Text.Json.JsonSerializer.Deserialize<List<int>>(v, (System.Text.Json.JsonSerializerOptions?)null) ?? new List<int>()
                    )
                    .HasColumnType("nvarchar(1000)")
                    .Metadata.SetValueComparer(intListComparer);
            });
            b.Entity<Payment>(e =>
            {
                e.ToTable(tb => tb.HasTrigger("Payment_Insert_Trigger"));
                e.Property(x => x.Amount).HasPrecision(18, 2);
            });
            b.Entity<StartingCash>(e =>
            {
                e.ToTable(tb => tb.HasTrigger("StartingCash_Trigger"));
            });
            b.Entity<Barcode>(e =>
            {
                e.ToTable(tb => tb.HasTrigger("Tr_Barcode_Audit"));
            });
            b.Entity<PosOrder>(e => 
            { 
                e.Property(x => x.Discount).HasPrecision(18, 2); 
                e.Property(x => x.Total).HasPrecision(18, 2); 
            });
            b.Entity<PosOrderItem>(e =>
            {
                e.Property(x => x.Discount).HasPrecision(18, 2);
                e.Property(x => x.Price).HasPrecision(18, 2);
                e.Property(x => x.Quantity).HasPrecision(18, 4);
            });
            b.Entity<PosVoid>(e =>
            {
                e.Property(x => x.Discount).HasPrecision(18, 2);
                e.Property(x => x.Price).HasPrecision(18, 2);
                e.Property(x => x.Quantity).HasPrecision(18, 4);
                e.Property(x => x.Total).HasPrecision(18, 2);
            });

            b.Entity<PromotionItem>(e =>
            {
                e.Property(x => x.Quantity).HasPrecision(18, 4);
                e.Property(x => x.QuantityLimit).HasPrecision(18, 4);
                e.Property(x => x.Value).HasPrecision(18, 2);
            });

            b.Entity<Stock>(e => 
                e.Property(x => x.Quantity).HasPrecision(18, 4));
            b.Entity<StockControl>(e =>
            {
                e.Property(x => x.LowStockWarningQuantity).HasPrecision(18, 4);
                e.Property(x => x.PreferredQuantity).HasPrecision(18, 4);
                e.Property(x => x.ReorderPoint).HasPrecision(18, 4);
            });

            b.Entity<Tax>(e => 
                e.Property(x => x.Rate).HasPrecision(9, 4));

            b.Entity<CustomerDiscount>(e => 
                e.Property(x => x.Value).HasPrecision(18, 2)
            );

            b.Entity<ProductTax>().HasKey(pt => new { pt.ProductId, pt.TaxId });

            b.Entity<Warehouse>(e =>
            {
                e.HasKey(x => x.Id);
                e.Property(x => x.Name).HasMaxLength(255).IsRequired();
            });


            //b.Entity<ApplicationProperty>()
            //    .HasOne<Company>()
            //    .WithMany()
            //    .HasForeignKey("CompanyId")
            //    .OnDelete(DeleteBehavior.Restrict); mat9dch tmsa7 company 7it id dyal company kayn f table dyal AP
        }
    }
}
