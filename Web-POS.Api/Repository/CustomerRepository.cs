using Microsoft.EntityFrameworkCore;
using Api.Models;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class CustomerRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Customer>> GetAllCustomers(int companyId)
        {
            return await _db.Customers
                .AsNoTracking()
                .Where(c => c.CompanyId == companyId)
                .Include(cn => cn.Country)
                .ToListAsync();
        }
        public async Task<Customer?> GetCustomerByIdAsync(int id, int companyId)
        {
            return await _db.Customers
            .AsNoTracking()
            .Include(b => b.Country)
            .FirstOrDefaultAsync(b => b.Id == id && b.CompanyId == companyId);
        }
        public async Task<Customer?> GetCustomerByNameAsync(string name, int companyId)
        {
            return await _db.Customers
                .AsNoTracking()
                .Include(b => b.Country)
                .FirstOrDefaultAsync(b => b.Name == name && b.CompanyId == companyId);
        }

        public Task<bool> ExistsByNameAsync(string name, int companyId)
        {
            return _db.Customers.AnyAsync(c => c.Name == name && c.CompanyId == companyId);
        }
        public async Task AddCustomerAsync(Customer newCustomer)
        {
            _db.Customers.Add(newCustomer);
            await _db.SaveChangesAsync();
        }        
        public async Task<bool> UpdateCustomerAsync(Customer customer)
        {
            _db.Customers.Update(customer);
            await _db.SaveChangesAsync();
            return true;
        }
        public async Task<bool> DeleteAsync(Customer customer)
        {
            _db.Customers.Remove(customer);
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
