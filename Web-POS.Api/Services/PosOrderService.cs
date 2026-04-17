using Api.Domain;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class PosOrderService
    {
        public readonly PosOrderRepository _repository;

        public PosOrderService(PosOrderRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosOrder> Create(int companyId, CreatePosOrderRequest req)
        {
            var strategy = _repository.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _repository.BeginTransactionAsync();

                try
                {
                    if (req.FloorPlanTableId.HasValue)
                    {
                        var table = await _repository.GetFloorPlanTableAsync(req.FloorPlanTableId.Value, companyId);

                        if (table == null)
                            throw new InvalidOperationException("Table not found.");

                        if (table.Status == 1)
                            throw new InvalidOperationException("This table is already occupied. Please select an existing order.");

                        table.UpdateStatus(1);
                        _repository.UpdateFloorPlanTable(table);
                    }

                    string orderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..4].ToUpper()}";

                    int defaultServiceStatus = 1;

                    var newOrder = PosOrder.Create(
                        companyId: companyId,
                        userId: req.UserId,
                        number: orderNumber,
                        discount: 0,
                        discountType: 0,
                        total: 0,
                        customerId: req.CustomerId,
                        serviceType: req.ServiceType,
                        serviceStatus: defaultServiceStatus,
                        floorPlanTableId: req.FloorPlanTableId
                    );

                    await _repository.AddAsync(newOrder);
                    await transaction.CommitAsync();

                    return newOrder;
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }

        public async Task<bool> Update(UpdatePosOrderRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, trackEntity: true);
            if (entity == null)
                throw new InvalidOperationException($"A PosOrder with the ID '{req.Id}' does not exist.");
            entity.Update(
                req.UserId,
                req.Number,
                req.Discount,
                req.DiscountType,
                req.Total,
                req.CustomerId,
                req.ServiceType,
                req.ServiceStatus,
                req.FloorPlanTableId
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null)
                return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}