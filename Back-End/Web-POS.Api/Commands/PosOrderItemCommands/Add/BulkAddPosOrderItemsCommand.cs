using MediatR;
using Api.Domain;
using Api.Models;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using System.Collections.Generic;

namespace Api.Commands.PosOrderItemCommands.Add
{
    public class BulkAddPosOrderItemsCommand : IRequest<BulkAddPosOrderItemsResponse>
    {
        public int CompanyId { get; set; }
        public int WarehouseId { get; set; }
        public decimal OrderTotal { get; set; }
        public List<BulkAddPosOrderItemRequest> Items { get; set; }

        /// When true, the pre-save out-of-stock check is skipped (stock may go
        /// negative). Used by offline sync (BatchSync): an offline sale already
        /// happened — replaying it must not be blocked by current stock, or the
        /// completed sale would be lost. The live cashier path leaves this false.
        public bool AllowNegativeStock { get; set; }

        public BulkAddPosOrderItemsCommand(int companyId, int warehouseId, decimal orderTotal, List<BulkAddPosOrderItemRequest> items, bool allowNegativeStock = false)
        {
            CompanyId = companyId;
            WarehouseId = warehouseId;
            OrderTotal = orderTotal;
            Items = items;
            AllowNegativeStock = allowNegativeStock;
        }

        public class BulkAddPosOrderItemsCommandHandler : IRequestHandler<BulkAddPosOrderItemsCommand, BulkAddPosOrderItemsResponse>
        {
            private readonly AppDbContext _db;

            public BulkAddPosOrderItemsCommandHandler(AppDbContext db)
            {
                _db = db;
            }

            public async Task<BulkAddPosOrderItemsResponse> Handle(BulkAddPosOrderItemsCommand command, CancellationToken cancellationToken)
            {
                var response = new BulkAddPosOrderItemsResponse();
                if (command.Items == null || !command.Items.Any())
                {
                    response.Success = false;
                    response.Message = "Item list cannot be empty.";
                    return response;
                }

                int posOrderId = command.Items.First().PosOrderId;
                var strategy = _db.Database.CreateExecutionStrategy();

                return await strategy.ExecuteAsync(async () =>
                {
                    using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

                    try
                    {
                        var orderToUpdate = await _db.PosOrders.FirstOrDefaultAsync(o => o.Id == posOrderId, cancellationToken);
                        if (orderToUpdate == null)
                        {
                            response.Success = false;
                            response.Message = "Order not found.";
                            return response;
                        }

                        var existingItems = await _db.PosOrderItems
                            .AsNoTracking()
                            .Include(i => i.Product)
                            .Where(i => i.PosOrderId == posOrderId && i.CompanyId == command.CompanyId)
                            .ToListAsync(cancellationToken);

                        var incomingProductIds = command.Items.Select(i => i.ProductId).ToList();
                        var allProductIds = incomingProductIds.Union(existingItems.Select(e => e.ProductId)).Distinct().ToList();
                        
                        var products = await _db.Products
                            .Where(p => allProductIds.Contains(p.Id))
                            .ToDictionaryAsync(p => p.Id, cancellationToken);

                        var stocks = await _db.Stocks
                            .Where(s => allProductIds.Contains(s.ProductId) && s.WarehouseId == command.WarehouseId && s.CompanyId == command.CompanyId)
                            .ToDictionaryAsync(s => s.ProductId, cancellationToken);

                        // --- Task 1: Pre-save Inventory Check (Delta Logic) ---
                        var preventNegInvProp = await _db.ApplicationProperties
                            .Where(ap => ap.CompanyId == command.CompanyId && ap.Name == "Order.PreventNegativeInventory")
                            .Select(ap => ap.Value)
                            .FirstOrDefaultAsync(cancellationToken);
                        bool preventNegativeInventory = !string.Equals(preventNegInvProp, "false", StringComparison.OrdinalIgnoreCase);

                        // Offline replays (BatchSync) bypass the block: the sale already
                        // happened offline, so it must post even if stock is now negative.
                        if (preventNegativeInventory && !command.AllowNegativeStock)
                        {
                            // Checked PER PRODUCT, not per line. A product may occupy
                            // several rows (`Order.SeparateRowForEachItem`), and the
                            // per-line form compared each row's quantity against the
                            // SAME existing row — so "2 × Coffee on two rows" was tested
                            // as two independent +2 deltas instead of one net +4, and a
                            // re-save of an unchanged order could even report a phantom
                            // shortage. The aggregate is what actually hits stock.
                            foreach (var group in command.Items.GroupBy(i => i.ProductId))
                            {
                                var product = products[group.Key];
                                if (product.IsService) continue;

                                decimal incoming = group.Sum(i => i.Quantity);
                                decimal current = existingItems
                                    .Where(e => e.ProductId == group.Key)
                                    .Sum(e => e.Quantity);
                                decimal delta = incoming - current;
                                if (delta <= 0) continue;

                                // Order lines are in the product's OWN unit (100 g),
                                // Stock is always in its category's reference unit
                                // (0.100 kg). Comparing the two unconverted would let a
                                // 100 g sale claim 100 kg of stock.
                                decimal deltaInStockUnit = UnitOfMeasure.ToReference(delta, product.UomId);

                                if (!stocks.TryGetValue(group.Key, out var stock) || stock.Quantity < deltaInStockUnit)
                                {
                                    // Fallback Check
                                    var otherWarehouses = await _db.Stocks
                                        .Include(s => s.Warehouse)
                                        .Where(s => s.ProductId == group.Key && s.WarehouseId != command.WarehouseId && s.Quantity >= deltaInStockUnit && s.CompanyId == command.CompanyId)
                                        .Select(s => s.Warehouse!.Name)
                                        .ToListAsync(cancellationToken);

                                    string whList = otherWarehouses.Any() ? string.Join(", ", otherWarehouses) : "None";
                                    response.Success = false;
                                    var unit = UnitOfMeasure.Get(product.UomId);
                                    response.Message = $"Product {product.Name} is out of stock in this warehouse (needed {decimal.Round(delta, unit.Digits)} {unit.Code} more). It is available in Warehouse(s): {whList}.";
                                    return response;
                                }
                            }
                        }

                        // --- Task 2: Deduct Stock (Delta) and Check Warnings ---
                        var warnings = new List<string>();

                        // 🚨 A product can legitimately appear on SEVERAL lines of one
                        // order — `Order.SeparateRowForEachItem` makes the POS add a new
                        // cart row per tap instead of incrementing, so "2 × Coffee, one
                        // with a comment" is two rows, not one.
                        //
                        // Every match below therefore pairs incoming lines to existing
                        // rows BY POSITION within their ProductId group. Matching on
                        // ProductId alone (`FirstOrDefault(e => e.ProductId == ...)`)
                        // silently corrupted such an order on every re-save: both
                        // incoming lines resolved to the SAME server row, so one row was
                        // written twice (last one wins), the other kept stale values,
                        // and the stock delta was computed twice against one quantity.
                        // Deleting one of the two lines was worse — `incomingProductIds`
                        // still contained the product, so neither row was removed and
                        // the deleted line survived server-side forever.
                        //
                        // The payload carries no line identity, and the client always
                        // sends the order's COMPLETE line set, so positional pairing
                        // within a product group is exact: same count → update in place,
                        // fewer → delete the surplus, more → insert the extras.
                        var incomingByProduct = command.Items
                            .GroupBy(i => i.ProductId)
                            .ToDictionary(g => g.Key, g => g.ToList());
                        var existingByProduct = existingItems
                            .GroupBy(e => e.ProductId)
                            .ToDictionary(g => g.Key, g => g.OrderBy(e => e.Id).ToList());

                        // 1. Handle items to remove (Add back stock). A product missing
                        // from the payload loses ALL its rows; a product whose line count
                        // dropped loses the surplus (the highest ids, so the oldest rows
                        // keep their identity).
                        var itemsToRemove = new List<PosOrderItem>();
                        foreach (var (productId, rows) in existingByProduct)
                        {
                            var keep = incomingByProduct.TryGetValue(productId, out var inc)
                                ? inc.Count
                                : 0;
                            if (rows.Count > keep)
                                itemsToRemove.AddRange(rows.Skip(keep));
                        }

                        foreach (var item in itemsToRemove)
                        {
                            if (!item.Product!.IsService)
                            {
                                if (stocks.TryGetValue(item.ProductId, out var stock))
                                {
                                    // Converted for the same reason as the check above:
                                    // the line is in the product's unit, stock is not.
                                    var restored = UnitOfMeasure.ToReference(item.Quantity, item.Product.UomId);
                                    stock.UpdateDetails(stock.Quantity + restored, stock.WarehouseId, stock.ProductId);
                                    _db.Stocks.Update(stock);
                                }
                            }
                        }

                        // Sync the items in DB
                        var trackingExistingItems = await _db.PosOrderItems
                            .Where(i => i.PosOrderId == posOrderId && i.CompanyId == command.CompanyId)
                            .ToListAsync(cancellationToken);

                        if (itemsToRemove.Any())
                        {
                            var idsToRemove = itemsToRemove.Select(x => x.Id).ToList();
                            var toRemove = trackingExistingItems.Where(x => idsToRemove.Contains(x.Id)).ToList();
                            _db.PosOrderItems.RemoveRange(toRemove);
                        }

                        // 2. Handle items to add/update, pairing by position WITHIN each
                        // ProductId group (see the note above) so an order carrying the
                        // same product on several rows round-trips intact.
                        var removedIds = itemsToRemove.Select(x => x.Id).ToHashSet();
                        var survivorsByProduct = trackingExistingItems
                            .Where(e => !removedIds.Contains(e.Id))
                            .GroupBy(e => e.ProductId)
                            .ToDictionary(g => g.Key, g => g.OrderBy(e => e.Id).ToList());
                        var takenPerProduct = new Dictionary<int, int>();

                        foreach (var req in command.Items)
                        {
                            var product = products[req.ProductId];
                            var slot = takenPerProduct.TryGetValue(req.ProductId, out var used) ? used : 0;
                            takenPerProduct[req.ProductId] = slot + 1;

                            PosOrderItem? existingItem = null;
                            if (survivorsByProduct.TryGetValue(req.ProductId, out var rows) && slot < rows.Count)
                                existingItem = rows[slot];

                            decimal oldQuantity = existingItem?.Quantity ?? 0;
                            decimal delta = req.Quantity - oldQuantity;

                            if (existingItem != null)
                            {
                                existingItem.UpdateDetails(
                                    req.Quantity, req.Price, req.Discount, req.DiscountType,
                                    req.DiscountAppliedType, req.Comment,
                                    req.DiscountInputValue, req.DiscountInputType
                                );
                                _db.PosOrderItems.Update(existingItem);
                            }
                            else
                            {
                                var newItem = PosOrderItem.Create(
                                    companyId: command.CompanyId, posOrderId: req.PosOrderId,
                                    productId: req.ProductId, roundNumber: req.RoundNumber,
                                    quantity: req.Quantity, price: req.Price, discount: req.Discount,
                                    discountType: req.DiscountType, discountAppliedType: req.DiscountAppliedType,
                                    comment: req.Comment, bundle: req.Bundle,
                                    discountInputValue: req.DiscountInputValue,
                                    discountInputType: req.DiscountInputType
                                );
                                _db.PosOrderItems.Add(newItem);
                            }

                            if (!product.IsService && delta != 0)
                            {
                                if (stocks.TryGetValue(req.ProductId, out var stock))
                                {
                                    decimal newStockQty = stock.Quantity - UnitOfMeasure.ToReference(delta, product.UomId);
                                    stock.UpdateDetails(newStockQty, stock.WarehouseId, req.ProductId);
                                    _db.Stocks.Update(stock);

                                    // StockControl Check (Only if we deducted or reached low levels)
                                    if (delta > 0)
                                    {
                                        var stockControl = await _db.StockControls
                                            .FirstOrDefaultAsync(sc => sc.ProductId == req.ProductId && sc.CompanyId == command.CompanyId, cancellationToken);
                                        
                                        if (stockControl != null)
                                        {
                                            if (stockControl.IsLowStockWarningEnabled && newStockQty <= stockControl.LowStockWarningQuantity)
                                            {
                                                var stockUnit = UnitOfMeasure.ReferenceOf(UnitOfMeasure.Get(product.UomId));
                                                warnings.Add($"Low stock warning: {product.Name} (Only {decimal.Round(newStockQty, stockUnit.Digits)} {stockUnit.Code} left)");
                                            }
                                            else if (newStockQty <= stockControl.ReorderPoint)
                                            {
                                                warnings.Add($"Reorder point reached for: {product.Name}");
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        await _db.SaveChangesAsync(cancellationToken);

                        // Sync taxes (rest of original logic)
                        var currentItems = await _db.PosOrderItems
                            .Where(i => i.PosOrderId == posOrderId && i.CompanyId == command.CompanyId)
                            .ToListAsync(cancellationToken);
                        var currentItemIds = currentItems.Select(i => i.Id).ToList();
                        var oldTaxes = await _db.Set<PosOrderItemTax>()
                            .Where(t => currentItemIds.Contains(t.PosOrderItemId))
                            .ToListAsync(cancellationToken);

                        if (oldTaxes.Any())
                        {
                            _db.Set<PosOrderItemTax>().RemoveRange(oldTaxes);
                        }

                        // Positional within the ProductId group, exactly as above:
                        // FirstOrDefault attached BOTH lines' taxes to the same row when
                        // a product occupied two, leaving the other row untaxed.
                        var savedByProduct = currentItems
                            .GroupBy(i => i.ProductId)
                            .ToDictionary(g => g.Key, g => g.OrderBy(i => i.Id).ToList());
                        var taxSlot = new Dictionary<int, int>();

                        foreach (var req in command.Items)
                        {
                            var slot = taxSlot.TryGetValue(req.ProductId, out var used) ? used : 0;
                            taxSlot[req.ProductId] = slot + 1;

                            PosOrderItem? savedItem = null;
                            if (savedByProduct.TryGetValue(req.ProductId, out var saved) && slot < saved.Count)
                                savedItem = saved[slot];

                            if (savedItem != null && req.AppliedTaxIds != null && req.AppliedTaxIds.Any())
                            {
                                foreach (var taxId in req.AppliedTaxIds)
                                {
                                    var newTax = new PosOrderItemTax
                                    {
                                        PosOrderItemId = savedItem.Id,
                                        TaxId = taxId,
                                        CompanyId = command.CompanyId
                                    };
                                    _db.Set<PosOrderItemTax>().Add(newTax);
                                }
                            }
                        }

                        decimal newTotal = command.OrderTotal;

                        orderToUpdate.Update(
                            orderToUpdate.UserId, orderToUpdate.Number, orderToUpdate.Discount,
                            orderToUpdate.DiscountType, newTotal, orderToUpdate.CustomerId,
                            orderToUpdate.ServiceType, orderToUpdate.ServiceStatus, orderToUpdate.FloorPlanTableId
                        );
                        _db.PosOrders.Update(orderToUpdate);

                        await _db.SaveChangesAsync(cancellationToken);
                        await transaction.CommitAsync(cancellationToken);

                        response.Success = true;
                        response.Warnings = warnings;
                        response.Message = "Items successfully added to the order.";
                        return response;
                    }
                    catch (Exception ex)
                    {
                        await transaction.RollbackAsync(cancellationToken);
                        response.Success = false;
                        response.Message = $"Error: {ex.Message}";
                        return response;
                    }
                });
            }
        }
    }
}