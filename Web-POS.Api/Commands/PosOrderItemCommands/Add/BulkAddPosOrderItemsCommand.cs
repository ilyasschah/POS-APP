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

        public BulkAddPosOrderItemsCommand(int companyId, int warehouseId, decimal orderTotal, List<BulkAddPosOrderItemRequest> items)
        {
            CompanyId = companyId;
            WarehouseId = warehouseId;
            OrderTotal = orderTotal;
            Items = items;
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

                        if (preventNegativeInventory)
                        {
                            foreach (var req in command.Items)
                            {
                                var product = products[req.ProductId];
                                if (product.IsService) continue;

                                var existingItem = existingItems.FirstOrDefault(e => e.ProductId == req.ProductId);
                                decimal oldQuantity = existingItem?.Quantity ?? 0;
                                decimal delta = req.Quantity - oldQuantity;

                                if (delta > 0)
                                {
                                    // We need more stock
                                    if (!stocks.TryGetValue(req.ProductId, out var stock) || stock.Quantity < delta)
                                    {
                                        // Fallback Check
                                        var otherWarehouses = await _db.Stocks
                                            .Include(s => s.Warehouse)
                                            .Where(s => s.ProductId == req.ProductId && s.WarehouseId != command.WarehouseId && s.Quantity >= delta && s.CompanyId == command.CompanyId)
                                            .Select(s => s.Warehouse.Name)
                                            .ToListAsync(cancellationToken);

                                        string whList = otherWarehouses.Any() ? string.Join(", ", otherWarehouses) : "None";
                                        response.Success = false;
                                        response.Message = $"Product {product.Name} is out of stock in this warehouse (needed {delta} more). It is available in Warehouse(s): {whList}.";
                                        return response;
                                    }
                                }
                            }
                        }

                        // --- Task 2: Deduct Stock (Delta) and Check Warnings ---
                        var warnings = new List<string>();

                        // 1. Handle items to remove (Add back stock)
                        var itemsToRemove = existingItems
                            .Where(e => !incomingProductIds.Contains(e.ProductId))
                            .ToList();

                        foreach (var item in itemsToRemove)
                        {
                            if (!item.Product.IsService)
                            {
                                if (stocks.TryGetValue(item.ProductId, out var stock))
                                {
                                    stock.UpdateDetails(stock.Quantity + item.Quantity, stock.WarehouseId, stock.ProductId);
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

                        // 2. Handle items to add/update
                        foreach (var req in command.Items)
                        {
                            var product = products[req.ProductId];
                            var existingItem = trackingExistingItems.FirstOrDefault(e => e.ProductId == req.ProductId);
                            decimal oldQuantity = existingItem?.Quantity ?? 0;
                            decimal delta = req.Quantity - oldQuantity;

                            if (existingItem != null)
                            {
                                existingItem.UpdateDetails(
                                    req.Quantity, req.Price, req.Discount, req.DiscountType,
                                    req.DiscountAppliedType, req.Comment
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
                                    comment: req.Comment, bundle: req.Bundle
                                );
                                _db.PosOrderItems.Add(newItem);
                            }

                            if (!product.IsService && delta != 0)
                            {
                                if (stocks.TryGetValue(req.ProductId, out var stock))
                                {
                                    decimal newStockQty = stock.Quantity - delta;
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
                                                warnings.Add($"Low stock warning: {product.Name} (Only {newStockQty} left)");
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

                        foreach (var req in command.Items)
                        {
                            var savedItem = currentItems.FirstOrDefault(i => i.ProductId == req.ProductId);

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