using Api.DataBase;
using Api.Domain;
using Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class PosOrderCheckoutService
    {
        private readonly AppDbContext _db;

        public PosOrderCheckoutService(AppDbContext db)
        {
            _db = db;
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

                    if (!posOrderItems.Any())
                        throw new InvalidOperationException("Cannot checkout an empty order.");

                    string documentNumber = $"INV-{DateTime.UtcNow:yyyyMMdd}-{posOrder.Id}";

                    decimal actualGrandTotal = 0;
                    var documentItems = new List<DocumentItem>();

                    foreach (var item in posOrderItems)
                    {
                        decimal itemTotal = item.Quantity * item.Price;
                        decimal priceAfterDiscount = item.Price - item.Discount;
                        decimal totalAfterDiscount = priceAfterDiscount * item.Quantity;

                        actualGrandTotal += totalAfterDiscount; 

                        var docItem = DocumentItem.Create(
                            companyId: companyId,
                            documentId: 0, 
                            productId: item.ProductId,
                            quantity: item.Quantity,
                            expectedQuantity: item.Quantity,
                            priceBeforeTax: item.Price,
                            price: item.Price,
                            discount: item.Discount,
                            discountType: item.DiscountType,
                            productCost: 0,
                            priceBeforeTaxAfterDiscount: priceAfterDiscount,
                            priceAfterDiscount: priceAfterDiscount,
                            total: itemTotal,
                            totalAfterDocumentDiscount: totalAfterDiscount,
                            discountApplyRule: false
                        );
                        documentItems.Add(docItem);
                    }

                    var document = Document.Create(
                        number: documentNumber,
                        userId: userId,
                        companyId: companyId,
                        documentTypeId: req.DocumentTypeId,
                        warehouseId: req.WarehouseId,
                        total: actualGrandTotal,
                        customerId: posOrder.CustomerId,
                        orderNumber: posOrder.Number,
                        discount: posOrder.Discount,
                        discountType: posOrder.DiscountType,
                        paidStatus: 1,
                        serviceType: posOrder.ServiceType
                    );

                    _db.Documents.Add(document);
                    await _db.SaveChangesAsync();

                    foreach (var docItem in documentItems)
                    {
                    }

                    var finalDocumentItems = documentItems.Select(item => DocumentItem.Create(
                            companyId: companyId, documentId: document.Id, productId: item.ProductId,
                            quantity: item.Quantity, expectedQuantity: item.Quantity, priceBeforeTax: item.PriceBeforeTax,
                            price: item.Price, discount: item.Discount, discountType: item.DiscountType,
                            productCost: 0, priceBeforeTaxAfterDiscount: item.PriceBeforeTaxAfterDiscount,
                            priceAfterDiscount: item.PriceAfterDiscount, total: item.Total,
                            totalAfterDocumentDiscount: item.TotalAfterDocumentDiscount, discountApplyRule: false
                    )).ToList();

                    _db.DocumentItems.AddRange(finalDocumentItems);

                    var payment = Payment.Create(
                        companyId: companyId,
                        documentId: document.Id,
                        paymentTypeId: req.PaymentTypeId,
                        amount: req.AmountPaid,
                        userId: userId
                    );
                    _db.Payments.Add(payment);

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