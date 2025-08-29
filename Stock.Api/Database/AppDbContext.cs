using Microsoft.EntityFrameworkCore;
using Stocks.Api.Domain;
namespace Stocks.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<Warehouse> Warehouses { get; set; }
        public DbSet<Stock> Stocks { get; set; }

    }
}
