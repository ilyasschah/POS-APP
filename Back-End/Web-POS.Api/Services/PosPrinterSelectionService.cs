using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PosPrinterSelectionService
    {
        private readonly PosPrinterSelectionRepository _repository;

        public PosPrinterSelectionService(PosPrinterSelectionRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosPrinterSelection> Create(CreatePosPrinterSelectionRequest req, int companyId)
        {
            if (await _repository.ExistsAsync(req.Key, companyId))
                throw new InvalidOperationException($"Printer selection with key '{req.Key}' already exists for this company.");

            var entity = PosPrinterSelection.Create(req.Key, req.PrinterName, req.IsEnabled ?? false);
            entity.CompanyId = companyId;
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdatePosPrinterSelectionRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"Printer selection with ID '{id}' not found.");

            var existingByKey = await _repository.GetByKeyAsync(req.Key);
            if (existingByKey != null && existingByKey.Id != id)
                throw new InvalidOperationException($"Another printer selection with key '{req.Key}' already exists.");

            entity.Update(req.Key, req.PrinterName, req.IsEnabled);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
