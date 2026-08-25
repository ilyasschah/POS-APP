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
        public DbSet<BarcodeRule> BarcodeRules { get; set; }
        public DbSet<SecurityKey> SecurityKeys { get; set; }
        public DbSet<ProductComment> ProductComments { get; set; }

        // ── Modifiers (see Domain/ModifierGroup.cs) ─────────────────────────
        // Catalogue: a group is company-level and shared across products, so the
        // link is its own table rather than a column on Product.
        public DbSet<ModifierGroup> ModifierGroups { get; set; }
        public DbSet<ModifierOption> ModifierOptions { get; set; }
        public DbSet<ProductModifierGroup> ProductModifierGroups { get; set; }
        // Per-line snapshots of what was actually chosen. Paired the same way
        // PosOrderItemTax / DocumentItemTax are: working state and the record.
        public DbSet<PosOrderItemModifier> PosOrderItemModifiers { get; set; }
        public DbSet<DocumentItemModifier> DocumentItemModifiers { get; set; }
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
        public DbSet<Shift> Shifts { get; set; }

        // ── POS sessions (see Domain/PosSessionStatus.cs) ───────────────────
        // `Shifts` above holds BOTH attendance shifts and POS sessions, told
        // apart by PosDeviceId — extended rather than duplicated.
        public DbSet<PosDevice> PosDevices { get; set; }
        public DbSet<PosSessionPaymentCount> PosSessionPaymentCounts { get; set; }
        public DbSet<ZReportCorrection> ZReportCorrections { get; set; }
        public DbSet<TimeClockEntry> TimeClockEntries { get; set; }
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
        public DbSet<PosPrinterSettings> PosPrinterSettings { get; set; }
        public DbSet<Template> Templates { get; set; }
        public DbSet<ZReport> ZReports { get; set; }
        public DbSet<PaymentType> PaymentTypes { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<Document> Documents { get; set; }
        public DbSet<DocumentCategory> DocumentCategories { get; set; }
        public DbSet<DocumentType> DocumentTypes { get; set; }
        public DbSet<DocumentItem> DocumentItems { get; set; }
        public DbSet<DocumentItemTax> DocumentItemTaxes { get; set; }
        public DbSet<DiscountLine> DiscountLines { get; set; }
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

        public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            StampLastModified();
            return base.SaveChangesAsync(cancellationToken);
        }

        public override int SaveChanges()
        {
            StampLastModified();
            return base.SaveChanges();
        }

        private void StampLastModified()
        {
            var now = DateTime.UtcNow;
            foreach (var entry in ChangeTracker.Entries<ISyncableEntity>())
            {
                if (entry.State == EntityState.Added || entry.State == EntityState.Modified)
                {
                    entry.Entity.LastModified = now;
                }
            }
        }
        protected override void OnModelCreating(ModelBuilder b)
        {

            base.OnModelCreating(b);

            // ── POS session model ───────────────────────────────────────────
            b.Entity<PosDevice>(e =>
            {
                // One register per (company, device GUID). The unique index is
                // the whole safety property: the client upserts by this pair on
                // every session open, so two rows for one terminal — and with
                // them two parallel "current" sessions — cannot exist.
                e.HasIndex(x => new { x.CompanyId, x.DeviceUid }).IsUnique();
            });

            b.Entity<Shift>(e =>
            {
                e.HasOne(x => x.PosDevice)
                 .WithMany()
                 .HasForeignKey(x => x.PosDeviceId)
                 .OnDelete(DeleteBehavior.Restrict);

                // A session opened offline is re-pushed until it lands; matching
                // on the client UUID is what makes that retry idempotent. Unique
                // per company, and FILTERED so the many attendance-shift rows
                // with a NULL LocalId do not collide with each other.
                e.HasIndex(x => new { x.CompanyId, x.LocalId })
                 .IsUnique()
                 .HasFilter("[LocalId] IS NOT NULL");

                // Drives "is this register already trading?" on every open.
                e.HasIndex(x => new { x.PosDeviceId, x.Status });
            });

            b.Entity<PosSessionPaymentCount>(e =>
            {
                e.HasOne(x => x.Session)
                 .WithMany()
                 .HasForeignKey(x => x.SessionId)
                 .OnDelete(DeleteBehavior.Cascade);

                e.HasOne(x => x.PaymentType)
                 .WithMany()
                 .HasForeignKey(x => x.PaymentTypeId)
                 .OnDelete(DeleteBehavior.Restrict);

                // One count per method per session.
                e.HasIndex(x => new { x.SessionId, x.PaymentTypeId }).IsUnique();
            });

            b.Entity<ZReportCorrection>(e =>
            {
                e.HasOne(x => x.Session)
                 .WithMany()
                 .HasForeignKey(x => x.SessionId)
                 .OnDelete(DeleteBehavior.Cascade);

                // One accumulating correction per (session, original report), so
                // a device reconnecting in batches updates counters instead of
                // emitting a row per push.
                e.HasIndex(x => new { x.SessionId, x.OriginalZReportId }).IsUnique();
            });

            // Session links on the transactional tables. All NULLABLE and all
            // Restrict: a session must never cascade-delete banked sales.
            b.Entity<PosOrder>()
             .HasOne<Shift>().WithMany()
             .HasForeignKey(x => x.SessionId)
             .OnDelete(DeleteBehavior.Restrict);

            b.Entity<Document>()
             .HasOne<Shift>().WithMany()
             .HasForeignKey(x => x.SessionId)
             .OnDelete(DeleteBehavior.Restrict);

            b.Entity<Payment>()
             .HasOne<Shift>().WithMany()
             .HasForeignKey(x => x.SessionId)
             .OnDelete(DeleteBehavior.Restrict);

            b.Entity<StartingCash>()
             .HasOne<Shift>().WithMany()
             .HasForeignKey(x => x.SessionId)
             .OnDelete(DeleteBehavior.Restrict);

            // The Z-report's boundary. Restrict for the same reason as the
            // others: a session must never cascade-delete a fiscal document.
            b.Entity<ZReport>()
             .HasOne<Shift>().WithMany()
             .HasForeignKey(x => x.SessionId)
             .OnDelete(DeleteBehavior.Restrict);

            b.Entity<ZReport>()
             .HasOne<PosDevice>().WithMany()
             .HasForeignKey(x => x.PosDeviceId)
             .OnDelete(DeleteBehavior.Restrict);

            // Drives the per-device number lookup on every close.
            b.Entity<ZReport>()
             .HasIndex(x => new { x.CompanyId, x.PosDeviceId });

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

            // Trigger names below are verified against sys.triggers. EF only needs to
            // know that *a* trigger exists on the table (so it omits the OUTPUT clause
            // on write); it never resolves the name. Do not infer a trigger's existence
            // or behaviour from these labels — query sys.triggers instead.
            b.Entity<Document>(e =>
            {
                e.ToTable(table => table.HasTrigger("trg_Document_CompanyConsistency"));
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
                .ToTable("FloorPlanTable", tb => tb.HasTrigger("trg_FloorPlanTable_CompanyConsistency"));

            b.Entity<Booking>(e =>
            {
                e.ToTable("Booking", tb => tb.HasTrigger("SomeTrigger"));

                var intListComparer = new ValueComparer<List<int>>(
                    (c1, c2) => c1 == null ? c2 == null : c2 != null && c1.SequenceEqual(c2),
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
                e.ToTable(tb => tb.HasTrigger("trg_Barcode_CompanyMatch"));
            });
            b.Entity<BarcodeRule>(e =>
            {
                // Stored as text, not the enum's int, so a nomenclature dumped
                // from the database is readable and so inserting a new member in
                // the middle of the enum can never re-point existing rows.
                e.Property(x => x.Type).HasConversion<string>().HasMaxLength(30);
                e.Property(x => x.Encoding).HasConversion<string>().HasMaxLength(10);

                // Every lookup is "all rules for this company, in order".
                e.HasIndex(x => new { x.CompanyId, x.Sequence });
            });
            // 🚨 Every modifier table below pins its Company foreign key to
            // NoAction, and it is not optional. `CompanyId` is a non-nullable
            // int, so EF's default for it is CASCADE — which gave SQL Server two
            // cascade paths into ModifierOption (Company → ModifierOption, and
            // Company → ModifierGroup → ModifierOption) and it refused the whole
            // migration with error 1785. The same shape threatens every child
            // table here, so the rule is applied uniformly rather than only
            // where it happened to bite first.
            //
            // Nothing is lost by it: deleting a Company row is not how this
            // system removes a company's data — CompanyDataResetService does
            // that explicitly, in the order it chooses.
            b.Entity<ModifierGroup>(e =>
            {
                // The admin screen and the sync both read "every group for this
                // company, in display order".
                e.HasIndex(x => new { x.CompanyId, x.Rank });

                e.HasOne(x => x.Company)
                 .WithMany()
                 .HasForeignKey(x => x.CompanyId)
                 .OnDelete(DeleteBehavior.NoAction);
            });
            b.Entity<ModifierOption>(e =>
            {
                // Deleting a group takes its options with it — an option outside
                // a group is not a thing the POS can render or price.
                e.HasOne(x => x.ModifierGroup)
                 .WithMany(g => g.Options)
                 .HasForeignKey(x => x.ModifierGroupId)
                 .OnDelete(DeleteBehavior.Cascade);

                e.HasIndex(x => new { x.ModifierGroupId, x.Rank });

                e.HasOne(x => x.Company)
                 .WithMany()
                 .HasForeignKey(x => x.CompanyId)
                 .OnDelete(DeleteBehavior.NoAction);
            });
            b.Entity<ProductModifierGroup>(e =>
            {
                // The POS asks this on every product tap: "does this product
                // have any groups?" It has to be an index seek, not a scan.
                e.HasIndex(x => new { x.CompanyId, x.ProductId, x.Rank });

                // One product cannot offer the same group twice — it would
                // render as two identical sections in the customise sheet.
                e.HasIndex(x => new { x.ProductId, x.ModifierGroupId }).IsUnique();

                // 🚨 NoAction on BOTH sides, deliberately. SQL Server refuses
                // multiple cascade paths into one table, and either cascade here
                // would also mean deleting a product or a group silently rewrites
                // what a live order is offering. The API deletes the links
                // explicitly instead.
                e.HasOne(x => x.Product)
                 .WithMany()
                 .HasForeignKey(x => x.ProductId)
                 .OnDelete(DeleteBehavior.NoAction);

                e.HasOne(x => x.ModifierGroup)
                 .WithMany()
                 .HasForeignKey(x => x.ModifierGroupId)
                 .OnDelete(DeleteBehavior.NoAction);

                e.HasOne(x => x.Company)
                 .WithMany()
                 .HasForeignKey(x => x.CompanyId)
                 .OnDelete(DeleteBehavior.NoAction);
            });
            b.Entity<PosOrderItemModifier>(e =>
            {
                // Removing a line takes its chosen modifiers with it.
                e.HasOne(x => x.PosOrderItem)
                 .WithMany()
                 .HasForeignKey(x => x.PosOrderItemId)
                 .OnDelete(DeleteBehavior.Cascade);

                e.HasIndex(x => new { x.PosOrderItemId, x.Rank });

                e.HasOne(x => x.Company)
                 .WithMany()
                 .HasForeignKey(x => x.CompanyId)
                 .OnDelete(DeleteBehavior.NoAction);
            });
            b.Entity<DocumentItemModifier>(e =>
            {
                e.HasOne(x => x.DocumentItem)
                 .WithMany()
                 .HasForeignKey(x => x.DocumentItemId)
                 .OnDelete(DeleteBehavior.Cascade);

                e.HasIndex(x => new { x.DocumentItemId, x.Rank });

                // The reporting query these tables exist for: sales of one
                // option across a period, for a company.
                e.HasIndex(x => new { x.CompanyId, x.ModifierOptionId });

                e.HasOne(x => x.Company)
                 .WithMany()
                 .HasForeignKey(x => x.CompanyId)
                 .OnDelete(DeleteBehavior.NoAction);
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
