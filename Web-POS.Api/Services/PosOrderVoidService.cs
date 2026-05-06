using Api.DataBase;
using Api.Domain;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class PosOrderVoidService
    {
        private readonly AppDbContext _db;
        private readonly DocumentsCounterRepository _counterRepo;

        public PosOrderVoidService(AppDbContext db, DocumentsCounterRepository counterRepo)
        {
            _db = db;
            _counterRepo = counterRepo;
        }

        public async Task<bool> VoidAsync(int companyId, int posOrderId, int warehouseId, int documentTypeId)
        {
            var strategy = _db.Database.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();

                try
                {
                    var posOrder = await _db.PosOrders
                        .FirstOrDefaultAsync(o => o.Id == posOrderId && o.CompanyId == companyId);

                    if (posOrder == null) return false;

                    var items = await _db.PosOrderItems
                        .Include(i => i.Product)
                        .Where(i => i.PosOrderId == posOrderId && i.CompanyId == companyId)
                        .ToListAsync();

                    // Generate a document number so syncOrderNumber on the client can
                    // still see this order's sequence number after it leaves PosOrders.
                    string yy = DateTime.UtcNow.ToString("yy");
                    string counterKey = $"DOC_{yy}_200_{companyId}";
                    var counter = await _counterRepo.GetByNameAsync(counterKey, trackEntity: true);
                    int nextValue;
                    if (counter == null)
                    {
                        nextValue = 1;
                        var newCounter = DocumentsCounter.Create(counterKey, nextValue, companyId);
                        await _counterRepo.AddAsync(newCounter);
                    }
                    else
                    {
                        nextValue = counter.Value + 1;
                        counter.UpdateValue(nextValue);
                        await _counterRepo.UpdateAsync(counter);
                    }
                    string documentNumber = $"{yy}-200-{nextValue.ToString().PadLeft(6, '0')}";

                    // paidStatus 99 = voided — distinct from normal paid (1) or unpaid (0)
                    var tombstone = Document.Create(
                        number: documentNumber,
                        userId: posOrder.UserId,
                        companyId: companyId,
                        documentTypeId: documentTypeId,
                        warehouseId: warehouseId,
                        total: 0,
                        customerId: posOrder.CustomerId,
                        orderNumber: posOrder.Number,
                        paidStatus: 99,
                        note: "VOID",
                        serviceType: posOrder.ServiceType
                    );
                    _db.Documents.Add(tombstone);
                    await _db.SaveChangesAsync();

                    // Restore stock for non-service items
                    foreach (var item in items)
                    {
                        if (item.Product != null && !item.Product.IsService)
                        {
                            var stock = await _db.Stocks
                                .FirstOrDefaultAsync(s =>
                                    s.ProductId == item.ProductId &&
                                    s.WarehouseId == warehouseId &&
                                    s.CompanyId == companyId);

                            if (stock != null)
                            {
                                stock.UpdateDetails(stock.Quantity + item.Quantity, stock.WarehouseId, stock.ProductId);
                                _db.Stocks.Update(stock);
                            }
                        }
                    }

                    // Free the floor plan table
                    if (posOrder.FloorPlanTableId.HasValue)
                    {
                        var table = await _db.FloorPlanTables
                            .FirstOrDefaultAsync(t => t.Id == posOrder.FloorPlanTableId.Value && t.CompanyId == companyId);
                        if (table != null)
                        {
                            table.UpdateStatus(0);
                            _db.FloorPlanTables.Update(table);
                        }
                    }

                    var itemIds = items.Select(i => i.Id).ToList();
                    var taxes = await _db.PosOrderItemTaxes
                        .Where(t => itemIds.Contains(t.PosOrderItemId) && t.CompanyId == companyId)
                        .ToListAsync();

                    if (taxes.Any()) _db.PosOrderItemTaxes.RemoveRange(taxes);
                    _db.PosOrderItems.RemoveRange(items);
                    _db.PosOrders.Remove(posOrder);

                    await _db.SaveChangesAsync();
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
