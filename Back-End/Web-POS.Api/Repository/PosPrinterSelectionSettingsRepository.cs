using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository
{
    public class PosPrinterSelectionSettingsRepository
    {
        private readonly AppDbContext _db;

        public PosPrinterSelectionSettingsRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<PosPrinterSelectionSettings>> GetAllAsync()
        {
            return await _db.PosPrinterSelectionSettings
                .AsNoTracking()
                .Include(x => x.PosPrinterSelection)
                .ToListAsync();
        }

        public async Task<List<PosPrinterSelectionSettings>> GetAllAsync(int companyId)
        {
            return await _db.PosPrinterSelectionSettings
                .Where(x => x.CompanyId == companyId)
                .AsNoTracking()
                .Include(x => x.PosPrinterSelection)
                .ToListAsync();
        }

        public async Task<PosPrinterSelectionSettings?> GetByIdAsync(int id, bool trackEntity = false)
        {
            var q = _db.PosPrinterSelectionSettings.AsQueryable();
            if (!trackEntity) q = q.AsNoTracking();
            return await q
                .Include(x => x.PosPrinterSelection)
                .FirstOrDefaultAsync(x => x.Id == id);
        }

        public async Task<List<PosPrinterSelectionSettings>> GetBySelectionIdAsync(int posPrinterSelectionId, int companyId)
        {
            return await _db.PosPrinterSelectionSettings
                .Where(x => x.PosPrinterSelectionId == posPrinterSelectionId && x.CompanyId == companyId)
                .AsNoTracking()
                .Include(x => x.PosPrinterSelection)
                .ToListAsync();
        }

        public async Task AddAsync(PosPrinterSelectionSettings entity)
        {
            _db.PosPrinterSelectionSettings.Add(entity);
            await _db.SaveChangesAsync();
        }

        public async Task UpdateAsync(PosPrinterSelectionSettings entity)
        {
            _db.PosPrinterSelectionSettings.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task DeleteAsync(PosPrinterSelectionSettings entity)
        {
            _db.PosPrinterSelectionSettings.Remove(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> SelectionExistsAsync(int selectionId)
        {
            return await _db.PosPrinterSelections.AnyAsync(s => s.Id == selectionId);
        }
    }
}
