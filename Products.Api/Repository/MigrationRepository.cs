using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class MigrationRepository
    {
        private readonly AppDbContext _db;

        public MigrationRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Migration>> GetAllAsync()
        {
            return await _db.Migrations
                .AsNoTracking()
                .OrderByDescending(m => m.Date)
                .ThenByDescending(m => m.Id)
                .ToListAsync();
        }

        public async Task<Migration?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.Migrations.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q.FirstOrDefaultAsync(m => m.Id == id);
        }

        public async Task<Migration?> GetByVersionAsync(string version)
        {
            return await _db.Migrations.AsNoTracking()
                .FirstOrDefaultAsync(m => m.Version == version);
        }

        public async Task<bool> ExistsByVersionAsync(string version)
        {
            return await _db.Migrations.AnyAsync(m => m.Version.ToLower() == version.ToLower());
        }

        public async Task AddAsync(Migration entity)
        {
            _db.Migrations.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Migration entity)
        {
            _db.Migrations.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Migration entity)
        {
            _db.Migrations.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
