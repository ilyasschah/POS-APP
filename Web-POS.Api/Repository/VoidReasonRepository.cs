using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Threading.Tasks;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class VoidReasonRepository
    {
        public readonly AppDbContext _db;

        public VoidReasonRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<VoidReason>> GetAllAsync()
        {
            return await _db.VoidReasons.AsNoTracking().ToListAsync();
        }

        public async Task<VoidReason?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var query = _db.VoidReasons.AsQueryable();
            if (!trackEntity)
            {
                query = query.AsNoTracking();
            }
            return await query.FirstOrDefaultAsync(vr => vr.Id == id);
        }

        public async Task<VoidReason?> GetByNameAsync(string name)
        {
            return await _db.VoidReasons.AsNoTracking().FirstOrDefaultAsync(vr => vr.Name == name);
        }

        public async Task<bool> ExistsAsync(string name)
        {
            return await _db.VoidReasons.AnyAsync(vr => vr.Name.ToLower() == name.ToLower());
        }

        public async Task AddAsync(VoidReason entity)
        {
            _db.VoidReasons.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(VoidReason entity)
        {
            _db.VoidReasons.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(VoidReason entity)
        {
            _db.VoidReasons.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}