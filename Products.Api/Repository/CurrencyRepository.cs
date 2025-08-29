using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class CurrencyRepository(AppDbContext db)
    {
        public AppDbContext _db = db;

        public async Task<List<Currency>> GetCurrenciesAsync()
        {
            return await _db.Currencys
                .AsNoTracking()
                .ToListAsync();
        }
        public async Task<Currency?> GetCurrencyById(int id)
        {
            return await _db.Currencys
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == id);
        }
        public async Task Add(Currency newCurrency)
        {
            _db.Currencys.Add(newCurrency);
            await _db.SaveChangesAsync();
        }

        public bool Exists(string code)
        {
            return _db.Currencys.Any(c => c.Code == code);
        }
        public async Task UpdateAsync(Currency currency)
        {
            _db.Currencys.Update(currency);
            await _db.SaveChangesAsync();
        }
        public async Task DeleteAsync(Currency currency)
        {
            _db.Currencys.Remove(currency);
            await _db.SaveChangesAsync();
        }
    }
}
