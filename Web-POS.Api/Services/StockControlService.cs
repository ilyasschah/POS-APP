// FILE: Products.Api.Services\StockControlService.cs

using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services;

public class StockControlService
{
    public readonly StockControlRepository _repository;

    public StockControlService(StockControlRepository repository)
    {
        _repository = repository;
    }

    public async Task<bool> Create(CreateStockControlRequest req)
    {
        if (_repository.ExistsForProduct(req.ProductId))
            throw new InvalidOperationException($"A StockControl for ProductId '{req.ProductId}' already exists.");

        var newEntity = StockControl.Create(req.ProductId);
        newEntity.Update(req.CustomerId, req.ReorderPoint, req.PreferredQuantity, req.IsLowStockWarningEnabled, req.LowStockWarningQuantity);

        await _repository.AddAsync(newEntity);
        return true;
    }

    public async Task<bool> Update(UpdateStockControlRequest req)
    {
        var entity = await _repository.GetByIdAsync(req.Id);
        if (entity == null)
            throw new InvalidOperationException($"A StockControl with the ID '{req.Id}' does not exist.");

        entity.Update(req.CustomerId, req.ReorderPoint, req.PreferredQuantity, req.IsLowStockWarningEnabled, req.LowStockWarningQuantity);

        await _repository.UpdateAsync(entity);
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var entity = await _repository.GetByIdAsync(id);
        if (entity == null)
            return false;

        await _repository.DeleteAsync(entity);
        return true;
    }
}
