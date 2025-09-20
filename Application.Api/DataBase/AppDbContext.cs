using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using System.Reflection.Metadata;
using System.Xml.Linq;
namespace Products.Api.DataBase
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }
        
    }
}
