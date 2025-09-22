using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository
{
    public class CustomerDiscountRepository(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        public async Task<List<CustomerDiscount>> GetAllCustomerDiscount()
        {
            return await _db.CustomerDiscounts
                .AsNoTracking()
                .Include(c => c.Customer)
                .ToListAsync();
        }
        public async Task Add(CustomerDiscount newcustomerdiscount)
        {
            _db.CustomerDiscounts.Add(newcustomerdiscount);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteQantityAsync(CustomerDiscount customerdiscount)
        {
            _db.CustomerDiscounts.Remove(customerdiscount);
            await _db.SaveChangesAsync();
        }
        //public bool Exist(int customerdiscountid)
        //{
        //    return _db.CustomerDiscounts.Any(cd => cd.Id == customerdiscountid);
        //}
    }
}