using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class CountryRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        // Global list — countries are shared across all companies.
        public async Task<List<Country>> GetAllCountries()
        {
            return await _db.Countries
                .AsNoTracking()
                .OrderBy(c => c.Name)
                .ToListAsync();
        }

        public async Task<Country?> GetCountryIdQuery(int id)
        {
            return await _db.Countries
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == id);
        }
    }
}
