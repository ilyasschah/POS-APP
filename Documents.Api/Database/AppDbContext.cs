using Documents.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Documents.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
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
