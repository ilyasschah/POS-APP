using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class StockControlService
    {
        public readonly StockControlRepository _repository;

        public StockControlService(StockControlRepository repository)
        {
            _repository = repository;
        }

        public async Task<bool> Create(CreateStockControlRequest req, int companyId)
        {
            if (await _repository.ExistsForProductAsync(req.ProductId, companyId))
                throw new InvalidOperationException($"A Stock Control rule for Product '{req.ProductId}' already exists.");

            var newEntity = StockControl.Create(req.ProductId, companyId);

            newEntity.Update(req.CustomerId, req.ReorderPoint, req.PreferredQuantity, req.IsLowStockWarningEnabled, req.LowStockWarningQuantity);

            await _repository.AddAsync(newEntity);
            return true;
        }

        public async Task<bool> Update(UpdateStockControlRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId)
                         ?? throw new InvalidOperationException($"A StockControl with the ID '{req.Id}' does not exist.");

            entity.Update(req.CustomerId, req.ReorderPoint, req.PreferredQuantity, req.IsLowStockWarningEnabled, req.LowStockWarningQuantity);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            if (entity == null)
                return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}