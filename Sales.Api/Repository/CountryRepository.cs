using Microsoft.EntityFrameworkCore;
using Sales.Api.DataBase;
using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Repository
{
    public class CountryRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Country>> GetAllCountries()
        {
            return await _db.Countries
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Country?> GetCountryIdQuery(int id)
        {
            return await _db.Countries
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id);
        }
        public bool Exists(string name)
        {
            return _db.Countries.Any(c => c.Name == name);
        }
        public async Task Add(Country newCountry)
        {
            _db.Countries.Add(newCountry);
            await _db.SaveChangesAsync();
        }        
        public async Task Update(Country country)
        {
            _db.Countries.Update(country);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(Country country)
        {
            _db.Countries.Remove(country);
            await _db.SaveChangesAsync();
        }
    }
}
