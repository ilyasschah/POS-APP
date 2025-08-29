using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
namespace Products.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<Currency> Currencys { get; set; }
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

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);


            modelBuilder.Entity<ProductGroup>()
                .HasOne(pg => pg.ParentGroup)
                .WithMany(pg => pg.ChildGroups)
                .HasForeignKey(pg => pg.ParentGroupId)
                .OnDelete(DeleteBehavior.NoAction);
            //modelBuilder.Entity<ProductComment>()
            //    .HasOne(pc => pc.Product)
            //  //.WithMany(p => p.Comments)
            //    .WithMany() // Or WithMany(p => p.Comments) if you add navigation property to Product
            //    .HasForeignKey(pc => pc.ProductId)
            //    .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<ProductTax>()
                .HasKey(pt => new { pt.ProductId, pt.TaxId });
        }
    
    }
}
