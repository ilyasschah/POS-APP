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
                using (var transaction = await _repository.BeginTransactionAsync())
                {
                    try
                    {
                        if (req.FloorPlanTableId.HasValue)
                        {
                            var table = await _repository.GetFloorPlanTableAsync(req.FloorPlanTableId.Value, companyId);
                            if (table != null)
                            {
                                table.UpdateStatus(req.ServiceStatus);
                                _repository.UpdateFloorPlanTable(table);
                            }
                        }

                        string orderNumber = string.IsNullOrWhiteSpace(req.Number)
                            ? $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..4].ToUpper()}"
                            : req.Number;

                        var newOrder = PosOrder.Create(
                            companyId: companyId,
                            userId: req.UserId,
                            number: orderNumber,
                            discount: req.Discount,
                            discountType: req.DiscountType,
                            total: req.Total,
                            customerId: req.CustomerId,
                            serviceType: req.ServiceType,
                            serviceStatus: req.ServiceStatus,
                            floorPlanTableId: req.FloorPlanTableId
                        );

                        await _repository.AddAsync(newOrder);
                        await transaction.CommitAsync();
                        return newOrder;
                    }
                    catch (Exception)
                    {
                        await transaction.RollbackAsync();
                        throw;
                    }
                }
            });
        }

        public async Task<bool> Update(int companyId, UpdatePosOrderRequest req)
        {
            var strategy = _repository.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using (var transaction = await _repository.BeginTransactionAsync())
                {
                    try
                    {
                        var order = await _repository.GetByIdAsync(req.Id, companyId, trackEntity: true);
                        if (order == null) return false;

                        order.Update(
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

                        // Sync Table Status
                        if (req.FloorPlanTableId.HasValue)
                        {
                            var table = await _repository.GetFloorPlanTableAsync(req.FloorPlanTableId.Value, companyId);
                            if (table != null)
                            {
                                table.UpdateStatus(req.ServiceStatus);
                                _repository.UpdateFloorPlanTable(table);
                            }
                        }

                        await _repository.UpdateAsync(order);
                        await transaction.CommitAsync();
                        return true;
                    }
                    catch (Exception)
                    {
                        await transaction.RollbackAsync();
                        throw;
                    }
                }
            });
        }
        public async Task<bool> UpdateStatus(int companyId, UpdatePosOrderStatusRequest req)
        {
            var strategy = _repository.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _repository.BeginTransactionAsync();
                try
                {
                    var order = await _repository.GetByIdAsync(req.Id, companyId);
                    if (order == null) return false;

                    // Update Order Status
                    order.Update(order.UserId, order.Number, order.Discount, order.DiscountType, order.Total, order.CustomerId, order.ServiceType, req.ServiceStatus, order.FloorPlanTableId);
                    await _repository.UpdateAsync(order);

                    // Sync Table Status
                    if (order.FloorPlanTableId.HasValue)
                    {
                        var table = await _repository.GetFloorPlanTableAsync(order.FloorPlanTableId.Value, companyId);
                        if (table != null)
                        {
                            table.UpdateStatus(req.ServiceStatus);
                            _repository.UpdateFloorPlanTable(table);
                        }
                    }

                    await _repository._db.SaveChangesAsync();
                    await transaction.CommitAsync();
                    return true;
                }
                catch (Exception)
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }
        public async Task<bool> Delete(int id, int companyId)
        {
            var strategy = _repository.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _repository.BeginTransactionAsync();

                try
                {
                    var order = await _repository.GetByIdAsync(id, companyId, trackEntity: true);
                    if (order == null) return false;

                    if (order.FloorPlanTableId.HasValue)
                    {
                        var table = await _repository.GetFloorPlanTableAsync(order.FloorPlanTableId.Value, companyId);
                        if (table != null)
                        {
                            table.UpdateStatus(0);
                            _repository.UpdateFloorPlanTable(table);
                        }
                    }

                    bool deleted = await _repository.DeleteAsync(id, companyId);

                    if (deleted)
                    {
                        await transaction.CommitAsync();
                        return true;
                    }

                    await transaction.RollbackAsync();
                    return false;
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }
    }
}