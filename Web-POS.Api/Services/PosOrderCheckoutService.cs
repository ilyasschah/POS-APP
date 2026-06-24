using Api.Constants;
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

                    // The client is responsible for sending a valid warehouse.
                    // As a safety net (e.g. a re-opened order whose warehouse
                    // context was lost), fall back to any warehouse belonging to
                    // the company so the Document's FK never fails.
                    int warehouseId = req.WarehouseId;
                    if (warehouseId <= 0 || !await _db.Warehouses.AnyAsync(w => w.Id == warehouseId))
                    {
                        warehouseId = await _db.Warehouses
                            .AsNoTracking()
                            .Where(w => w.CompanyId == companyId)
                            .Select(w => (int?)w.Id)
                            .FirstOrDefaultAsync()
                            ?? throw new InvalidOperationException($"Warehouse {req.WarehouseId} not found and company {companyId} has no warehouse to fall back to.");
                    }

                    string documentNumber;
                    if (!string.IsNullOrWhiteSpace(req.ClientDocumentNumber))
                    {
                        // Offline-first: the client issued a device-local number at
                        // checkout (e.g. CAISSE1-200-000045). Keep it verbatim so the
                        // printed/scanned receipt never changes after sync — and no
                        // server counter is consumed (the device owns its sequence).
                        documentNumber = req.ClientDocumentNumber.Trim();
                    }
                    else
                    {
                        // Online / legacy path: generate the server sequence YY-CCC-NNNNNN.
                        string yy = DateTime.UtcNow.ToString("yy");
                        string counterKey = $"DOC_{yy}_{DocumentTypeConstants.SalesCode}_{companyId}";
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
                        documentNumber = $"{yy}-{DocumentTypeConstants.SalesCode}-{nextValue.ToString().PadLeft(6, '0')}";
                    }

                    // Default null customer to Walk-In (Code = "C000")
                    int? effectiveCustomerId = posOrder.CustomerId;
                    if (effectiveCustomerId == null || effectiveCustomerId == 0)
                    {
                        effectiveCustomerId = await _db.Customers
                            .Where(c => c.CompanyId == companyId && c.Code == "C000")
                            .Select(c => (int?)c.Id)
                            .FirstOrDefaultAsync();
                    }

                    // Rule 2: respect the PaymentType's MarkAsPaid flag so that
                    // credit/tab payment types leave the document as Unpaid (0).
                    var paymentType = await _db.PaymentTypes
                        .AsNoTracking()
                        .FirstOrDefaultAsync(pt => pt.Id == req.PaymentTypeId);
                    int paidStatus = (paymentType?.MarkAsPaid ?? true) ? 1 : 0;

                    // Rule 3: calculate DueDate from the DefaultDueDateDays setting.
                    var dueDateProp = await _db.ApplicationProperties
                        .Where(ap => ap.CompanyId == companyId && ap.Name == "Order.DefaultDueDateDays")
                        .Select(ap => ap.Value)
                        .FirstOrDefaultAsync();
                    int dueDateDays = int.TryParse(dueDateProp, out var parsedDays) ? parsedDays : 0;
                    DateTime? calculatedDueDate = dueDateDays > 0
                        ? DateTime.UtcNow.Date.AddDays(dueDateDays)
                        : (DateTime?)null;

                    var document = Document.Create(
                        number: documentNumber,
                        userId: userId,
                        companyId: companyId,
                        documentTypeId: req.DocumentTypeId,
                        warehouseId: warehouseId,
                        total: documentGrandTotal,
                        customerId: effectiveCustomerId,
                        orderNumber: req.OrderNumber ?? posOrder.Number,
                        discount: posOrder.Discount,
                        discountType: posOrder.DiscountType,
                        paidStatus: paidStatus,
                        serviceType: posOrder.ServiceType,
                        dueDate: calculatedDueDate
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

                    var booking = await _db.Bookings
                        .FirstOrDefaultAsync(b => b.PosOrderId == posOrder.Id && b.CompanyId == companyId);

                    if (booking != null)
                    {
                        booking.UpdateStatus(4, document.Id); // Completed + link receipt
                        foreach (var tableId in booking.TableIds)
                        {
                            var t = await _db.FloorPlanTables.FirstOrDefaultAsync(t => t.Id == tableId && t.CompanyId == companyId);
                            if (t != null) { t.UpdateStatus(0); _db.FloorPlanTables.Update(t); }
                        }
                    }
                    else if (posOrder.FloorPlanTableId.HasValue)
                    {
                        var table = await _db.FloorPlanTables.FirstOrDefaultAsync(t => t.Id == posOrder.FloorPlanTableId.Value && t.CompanyId == companyId);
                        if (table != null) { table.UpdateStatus(0); _db.FloorPlanTables.Update(table); }
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