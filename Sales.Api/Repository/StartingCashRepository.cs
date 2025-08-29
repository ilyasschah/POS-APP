using Microsoft.EntityFrameworkCore;
using Sales.Api.DataBase;
using Sales.Api.Domain;

namespace Sales.Api.Repository
{
    public class StartingCashRepository
    {
        public readonly AppDbContext _db;

        public StartingCashRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<StartingCash>> GetAllAsync()
        {
            return await _db.StartingCashs
                .Include(sc => sc.User)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<StartingCash?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.StartingCashs.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query
                .Include(sc => sc.User)
                .FirstOrDefaultAsync(sc => sc.Id == id);
        }

        public async Task<List<StartingCash>> GetByUserIdAsync(int userId)
        {
            return await _db.StartingCashs
                .Where(sc => sc.UserId == userId)
                .Include(sc => sc.User)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task AddAsync(StartingCash entity)
        {
            _db.StartingCashs.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(StartingCash entity)
        {
            _db.StartingCashs.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}