using Microsoft.EntityFrameworkCore;
using Sales.Api.DataBase;
using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Repository
{
    public class CustomerRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Customer>> GetAllCustomers()
        {
            return await _db.Customers
                .AsNoTracking()
                .Include(cn => cn.Country)
                .ToListAsync();
        }
        public async Task<Customer?> GetCustomerByNameQuery(string name)
        {
            return await _db.Customers
            .AsNoTracking()
            .Include(b => b.Country)
            .FirstOrDefaultAsync(b => b.Name == name);
        }
        public bool Exists(string name)
        {
            return _db.Customers.Any(c => c.Name == name);
        }
        public async Task Add(Customer newCustomer)
        {
            _db.Customers.Add(newCustomer);
            await _db.SaveChangesAsync();
        }        
        public async Task UpdateAsync(Customer customer)
        {
            _db.Customers.Update(customer);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(Customer customer)
        {
            _db.Customers.Remove(customer);
            await _db.SaveChangesAsync();
        }
    }
}
