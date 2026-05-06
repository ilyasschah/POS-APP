using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class PosOrderCheckoutService
    {
        private readonly AppDbContext _db;
        private readonly DocumentsCounterRepository _counterRepo;

        public PosOrderCheckoutService(AppDbContext db, DocumentsCounterRepository counterRepo)
        {
            _db = db;
            _counterRepo = counterRepo;
        }

        public async Task<Document> CheckoutAsync(int companyId, int userId, CheckoutPosOrderRequest req)
        {
            var strategy = _db.Database.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();

                try
                {
                    var posOrder = await _db.PosOrders
                        .FirstOrDefaultAsync(o => o.Id == req.PosOrderId && o.CompanyId == companyId);

                    if (posOrder == null)
                        throw new InvalidOperationException("Order not found.");

                    var posOrderItems = await _db.PosOrderItems
                        .Where(i => i.PosOrderId == req.PosOrderId && i.VoidedBy == null)
                        .ToListAsync();

                    if (!posOrderItems.Any() || req.Items == null || !req.Items.Any())
                        throw new InvalidOperationException("Cannot checkout an empty order.");

                    var posOrderItemIds = posOrderItems.Select(i => i.Id).ToList();
                    var cartTaxes = await _db.PosOrderItemTaxes
                        .Where(t => posOrderItemIds.Contains(t.PosOrderItemId) && t.CompanyId == companyId)
                        .ToListAsync();

                    decimal documentGrandTotal = req.GrandTotal;

                    // Enterprise document numbering: YY-CCC-NNNNNN
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

                    // Default null customer to Walk-In (Code = "C000")
                    int? effectiveCustomerId = posOrder.CustomerId;
                    if (effectiveCustomerId == null || effectiveCustomerId == 0)
                    {
                        effectiveCustomerId = await _db.Customers
                            .Where(c => c.CompanyId == companyId && c.Code == "C000")
                            .Select(c => (int?)c.Id)
                            .FirstOrDefaultAsync();
                    }

                    var document = Document.Create(
                        number: documentNumber,
                        userId: userId,
                        companyId: companyId,
                        documentTypeId: req.DocumentTypeId,
                        warehouseId: req.WarehouseId,
                        total: documentGrandTotal,
                        customerId: effectiveCustomerId,
                        orderNumber: req.OrderNumber ?? posOrder.Number,
                        discount: posOrder.Discount,
                        discountType: posOrder.DiscountType,
                        paidStatus: 1,
                        serviceType: posOrder.ServiceType
                    );

                    _db.Documents.Add(document);
                    await _db.SaveChangesAsync(); 
                    var productIds = posOrderItems.Select(i => i.ProductId).Distinct().ToList();
                    var productCosts = await _db.Products
                        .Where(p => productIds.Contains(p.Id) && p.CompanyId == companyId)
                        .ToDictionaryAsync(p => p.Id, p => p.Cost);
                    foreach (var frontendItem in req.Items)
                    {
                        var originalCartItem = posOrderItems.FirstOrDefault(i => i.ProductId == frontendItem.ProductId);
                        if (originalCartItem == null) continue;

                        var docItem = DocumentItem.Create(
                            companyId: companyId,
                            documentId: document.Id,
                            productId: originalCartItem.ProductId,
                            quantity: originalCartItem.Quantity,
                            expectedQuantity: originalCartItem.Quantity,
                            priceBeforeTax: originalCartItem.Price,
                            price: originalCartItem.Price,
                            discount: originalCartItem.Discount,
                            discountType: originalCartItem.DiscountType,
                            productCost: productCosts.ContainsKey(originalCartItem.ProductId) ? productCosts[originalCartItem.ProductId] : 0,
                            priceBeforeTaxAfterDiscount: frontendItem.PriceBeforeTaxAfterDiscount,
                            priceAfterDiscount: frontendItem.PriceAfterDiscount,
                            total: frontendItem.Total,
                            totalAfterDocumentDiscount: frontendItem.TotalAfterDocumentDiscount,
                            discountApplyRule: false
                        );

                        _db.DocumentItems.Add(docItem);
                        await _db.SaveChangesAsync();

                        if (frontendItem.Taxes != null && frontendItem.Taxes.Any())
                        {
                            foreach (var taxDto in frontendItem.Taxes)
                            {
                                var docTax = DocumentItemTax.Create(
                                    documentItemId: docItem.Id,
                                    taxId: taxDto.TaxId,
                                    amount: taxDto.Amount,
                                    companyId: companyId
                                );
                                _db.Add(docTax);
                            }
                        }
                    }

                    await _db.SaveChangesAsync();

                    var payment = Payment.Create(
                        companyId: companyId,
                        documentId: document.Id,
                        paymentTypeId: req.PaymentTypeId,
                        amount: req.AmountPaid,
                        userId: userId
                    );
                    _db.Payments.Add(payment);

                    if (cartTaxes.Any())
                        _db.PosOrderItemTaxes.RemoveRange(cartTaxes);

                    _db.PosOrderItems.RemoveRange(posOrderItems);

                    if (posOrder.FloorPlanTableId.HasValue)
                    {
                        var table = await _db.FloorPlanTables.FirstOrDefaultAsync(t => t.Id == posOrder.FloorPlanTableId.Value && t.CompanyId == companyId);
                        if (table != null)
                        {
                            table.UpdateStatus(0);
                            _db.FloorPlanTables.Update(table);
                        }
                    }

                    _db.PosOrders.Remove(posOrder);
                    await _db.SaveChangesAsync();
                    await transaction.CommitAsync();

                    return document;
                }
                catch (Exception)
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }
    }
}