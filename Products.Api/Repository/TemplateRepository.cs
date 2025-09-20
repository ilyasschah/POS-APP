using Microsoft.EntityFrameworkCore;
using Products.Api.DataBase;
using Products.Api.Domain;

namespace Products.Api.Repository
{
    public class TemplateRepository
    {
        private readonly AppDbContext _db;

        public TemplateRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<Template>> GetAllAsync()
        {
            return await _db.Templates.AsNoTracking().ToListAsync();
        }

        public async Task<Template?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.Templates.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q.FirstOrDefaultAsync(t => t.Id == id);
        }

        public async Task<Template?> GetByNameAsync(string name)
        {
            return await _db.Templates.AsNoTracking()
                .FirstOrDefaultAsync(t => t.Name == name);
        }

        public async Task<bool> ExistsByNameAsync(string name)
        {
            return await _db.Templates.AnyAsync(t => t.Name.ToLower() == name.ToLower());
        }

        public async Task AddAsync(Template entity)
        {
            _db.Templates.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(Template entity)
        {
            _db.Templates.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(Template entity)
        {
            _db.Templates.Remove(entity);
            await _db.SaveChangesAsync();
        }
    }
}
