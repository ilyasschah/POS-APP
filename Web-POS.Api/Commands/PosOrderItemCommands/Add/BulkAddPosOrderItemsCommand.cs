using MediatR;
using Api.Domain;
using Api.Models;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.PosOrderItemCommands.Add
{
    public class BulkAddPosOrderItemsCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public List<BulkAddPosOrderItemRequest> Items { get; set; }

        public BulkAddPosOrderItemsCommand(int companyId, List<BulkAddPosOrderItemRequest> items)
        {
            CompanyId = companyId;
            Items = items;
        }

        public class BulkAddPosOrderItemsCommandHandler : IRequestHandler<BulkAddPosOrderItemsCommand, bool>
        {
            private readonly AppDbContext _db;

            public BulkAddPosOrderItemsCommandHandler(AppDbContext db)
            {
                _db = db;
            }

            public async Task<bool> Handle(BulkAddPosOrderItemsCommand command, CancellationToken cancellationToken)
            {
                if (command.Items == null || !command.Items.Any())
                    return false;

                int posOrderId = command.Items.First().PosOrderId;
                var strategy = _db.Database.CreateExecutionStrategy();

                return await strategy.ExecuteAsync(async () =>
                {
                    using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

                    try
                    {
                        var existingItems = await _db.PosOrderItems
                            .Where(i => i.PosOrderId == posOrderId && i.CompanyId == command.CompanyId)
                            .ToListAsync(cancellationToken);

                        var incomingProductIds = command.Items.Select(i => i.ProductId).ToList();

                        var itemsToRemove = existingItems
                            .Where(e => !incomingProductIds.Contains(e.ProductId))
                            .ToList();

                        if (itemsToRemove.Any())
                        {
                            _db.PosOrderItems.RemoveRange(itemsToRemove);
                        }

                        foreach (var req in command.Items)
                        {
                            var existingItem = existingItems.FirstOrDefault(e => e.ProductId == req.ProductId);

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
                        }

                        await _db.SaveChangesAsync(cancellationToken);

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

                        var orderToUpdate = await _db.PosOrders.FirstOrDefaultAsync(o => o.Id == posOrderId, cancellationToken);
                        if (orderToUpdate != null)
                        {
                            decimal newTotal = currentItems.Sum(i => (i.Price - i.Discount) * i.Quantity);

                            orderToUpdate.Update(
                                orderToUpdate.UserId, orderToUpdate.Number, orderToUpdate.Discount,
                                orderToUpdate.DiscountType, newTotal, orderToUpdate.CustomerId,
                                orderToUpdate.ServiceType, orderToUpdate.ServiceStatus, orderToUpdate.FloorPlanTableId
                            );
                            _db.PosOrders.Update(orderToUpdate);
                        }

                        await _db.SaveChangesAsync(cancellationToken);
                        await transaction.CommitAsync(cancellationToken);
                        return true;
                    }
                    catch
                    {
                        await transaction.RollbackAsync(cancellationToken);
                        throw;
                    }
                });
            }
        }
    }
}