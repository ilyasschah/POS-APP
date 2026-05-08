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

                        int? effectiveCustomerId = req.CustomerId;
                        if (!effectiveCustomerId.HasValue || effectiveCustomerId == 0)
                        {
                            effectiveCustomerId = await _repository._db.Customers
                                .Where(c => c.CompanyId == companyId && c.Code == "C000")
                                .Select(c => (int?)c.Id)
                                .FirstOrDefaultAsync();
                        }

                        var newOrder = PosOrder.Create(
                            companyId: companyId,
                            userId: req.UserId,
                            number: req.Number ?? "New Order",
                            discount: req.Discount,
                            discountType: req.DiscountType,
                            total: req.Total,
                            customerId: effectiveCustomerId,
                            serviceType: req.ServiceType,
                            serviceStatus: req.ServiceStatus,
                            floorPlanTableId: req.FloorPlanTableId
                        );

                        await _repository.AddAsync(newOrder);

                        // Link booking → order. AddAsync already called SaveChangesAsync so
                        // newOrder.Id is now the real DB identity value.
                        if (req.BookingId.HasValue)
                        {
                            var booking = await _repository._db.Bookings
                                .FirstOrDefaultAsync(b => b.Id == req.BookingId.Value && b.CompanyId == companyId);
                            if (booking != null)
                            {
                                booking.LinkPosOrder(newOrder.Id);
                                booking.UpdateStatus(3); // In Service
                                await _repository._db.SaveChangesAsync(); // flush booking changes before commit
                            }
                        }

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

                        // When service type changes away from Dine-In (0), free and clear
                        // any tables that were reserved on the linked booking.
                        if (req.ServiceType != 0)
                        {
                            var booking = await _repository._db.Bookings
                                .FirstOrDefaultAsync(b => b.PosOrderId == req.Id && b.CompanyId == companyId);
                            if (booking != null && booking.TableIds.Count > 0)
                            {
                                foreach (var tableId in booking.TableIds)
                                {
                                    var t = await _repository._db.FloorPlanTables
                                        .FirstOrDefaultAsync(t => t.Id == tableId && t.CompanyId == companyId);
                                    if (t != null) { t.UpdateStatus(0); _repository._db.FloorPlanTables.Update(t); }
                                }
                                // Replace the list reference so EF Core detects the change
                                // (in-place .Clear() is invisible to the JSON ValueConverter).
                                booking.UpdateResource(booking.UserId, new List<int>());
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
        public async Task<bool> Delete(int id, int companyId, int warehouseId)
        {
            var strategy = _repository.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _repository.BeginTransactionAsync();

                try
                {
                    var order = await _repository._db.PosOrders
                        .Include(o => o.User)
                        .Include(o => o.Customer)
                        .FirstOrDefaultAsync(o => o.Id == id && o.CompanyId == companyId);

                    if (order == null) return false;

                    var items = await _repository._db.PosOrderItems
                        .Include(i => i.Product)
                        .Where(i => i.PosOrderId == id && i.CompanyId == companyId)
                        .ToListAsync();

                    foreach (var item in items)
                    {
                        if (item.Product != null && !item.Product.IsService)
                        {
                            var stock = await _repository._db.Stocks
                                .FirstOrDefaultAsync(s => s.ProductId == item.ProductId && s.WarehouseId == warehouseId && s.CompanyId == companyId);
                            
                            if (stock != null)
                            {
                                stock.UpdateDetails(stock.Quantity + item.Quantity, stock.WarehouseId, stock.ProductId);
                                _repository._db.Stocks.Update(stock);
                            }
                        }
                    }

                    if (order.FloorPlanTableId.HasValue)
                    {
                        var table = await _repository.GetFloorPlanTableAsync(order.FloorPlanTableId.Value, companyId);
                        if (table != null)
                        {
                            table.UpdateStatus(0);
                            _repository.UpdateFloorPlanTable(table);
                        }
                    }

                    _repository._db.PosOrderItems.RemoveRange(items);
                    _repository._db.PosOrders.Remove(order);
                    await _repository._db.SaveChangesAsync();

                    await transaction.CommitAsync();
                    return true;
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