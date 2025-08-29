using Microsoft.EntityFrameworkCore;
using Application.Api.Domain;
namespace Application.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<ApplicationProperty> ApplicationProperties { get; set; }
        public DbSet<Migration> Migrations  { get; set; }
        public DbSet<PosPrinterSelection> PosPrinterSelections  { get; set; }
        public DbSet<PosPrinterSettings> PosPrinterSettings  { get; set; }
        public DbSet<PosPrinterSelectionSettings> PosPrinterSelectionSettings  { get; set; }
        public DbSet<Template> Templates  { get; set; }
    }
}
