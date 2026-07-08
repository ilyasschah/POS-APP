using Microsoft.EntityFrameworkCore;
using Products.Api.Domain;
using Products.Api.DataBase;

namespace Products.Api.Repository
{
    public class StartingCashRepository
    {
        private readonly AppDbContext _db;

        public StartingCashRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<StartingCash>> GetAllAsync()
        {
            return await _db.StartingCashes
                .AsNoTracking()
                .Include(sc => sc.User)
                .ToListAsync();
        }

        public async Task<StartingCash?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.StartingCashes.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();

            return await q
                .Include(sc => sc.User)
                .FirstOrDefaultAsync(sc => sc.Id == id);
        }

        public async Task<List<StartingCash>> GetByUserIdAsync(int userId)
        {
            return await _db.StartingCashes
                .AsNoTracking()
                .Where(sc => sc.UserId == userId)
                .Include(sc => sc.User)
                .OrderByDescending(sc => sc.DateCreated)
                .ToListAsync();
        }

        public async Task AddAsync(StartingCash entity)
        {
            _db.StartingCashes.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(StartingCash entity)
        {
            _db.StartingCashes.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(StartingCash entity)
        {
            _db.StartingCashes.Remove(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> UserExistsAsync(int userId)
        {
            return await _db.Users.AnyAsync(u => u.Id == userId);
        }
    }
}
