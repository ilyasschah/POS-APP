using Microsoft.EntityFrameworkCore;
using Sales.Api.Domain;
namespace Sales.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        public DbSet<Customer> Customers { get; set; }
        public DbSet<Country> Countries { get; set; }
        public DbSet<CustomerDiscount> CustomerDiscounts { get; set; }
        public DbSet<Company> Companies { get;  set; }
        public DbSet<StockControl> StockControls { get;  set; }
        public DbSet<LoyaltyCard> LoyaltyCards { get;  set; }
        public DbSet<User> Users { get;  set; }
        public DbSet<PosOrder> PosOrders { get;  set; }
        public DbSet<PosVoid> PosVoids { get;  set; }
        public DbSet<PosOrderItem> PosOrderItems { get;  set; }
        public DbSet<FloorPlan> FloorPlans { get; set; }
        public DbSet<FloorPlanTable> FloorPlanTables { get; set; }
        public DbSet<StartingCash> StartingCashes { get; set; }
    }
}
