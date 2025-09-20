using Documents.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Documents.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        
    }
}
