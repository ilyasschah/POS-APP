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
            // 1. Fetch the Cart and its Items
            var posOrder = await _db.PosOrders
                .FirstOrDefaultAsync(o => o.Id == req.PosOrderId && o.CompanyId == companyId);

            if (posOrder == null)
                throw new InvalidOperationException("Order not found.");

            var posOrderItems = await _db.PosOrderItems
                .Where(i => i.PosOrderId == req.PosOrderId && i.VoidedBy == null) // Ignore voided items!
                .ToListAsync();

            if (!posOrderItems.Any())
                throw new InvalidOperationException("Cannot checkout an empty order.");

            // ✨ START TRANSACTION ✨
            using var transaction = await _db.Database.BeginTransactionAsync();

            try
            {
                // 2. Generate Invoice Number (e.g., INV-20260409-1)
                string documentNumber = $"INV-{DateTime.UtcNow:yyyyMMdd}-{posOrder.Id}";

                // 3. Create Document (Save Document as Payed)
                var document = Document.Create(
                    number: documentNumber,
                    userId: userId,
                    companyId: companyId,
                    documentTypeId: req.DocumentTypeId,
                    warehouseId: req.WarehouseId,
                    total: posOrder.Total ?? 0,
                    customerId: posOrder.CustomerId,
                    orderNumber: posOrder.Number, // Save the old cart number for reference
                    discount: posOrder.Discount,
                    discountType: posOrder.DiscountType,
                    paidStatus: 1, // 1 = Paid
                    serviceType: posOrder.ServiceType
                );

                _db.Documents.Add(document);
                await _db.SaveChangesAsync(); // Save now to generate the Document.Id for the items

                // 4. Map PosOrderItems to DocumentItems
                var documentItems = new List<DocumentItem>();
                foreach (var item in posOrderItems)
                {
                    decimal itemTotal = item.Quantity * item.Price;
                    decimal priceAfterDiscount = item.Price - item.Discount;
                    decimal totalAfterDiscount = priceAfterDiscount * item.Quantity;

                    var docItem = DocumentItem.Create(
                        companyId: companyId,
                        documentId: document.Id,
                        productId: item.ProductId,
                        quantity: item.Quantity,
                        expectedQuantity: item.Quantity,
                        priceBeforeTax: item.Price,
                        price: item.Price,
                        discount: item.Discount,
                        discountType: item.DiscountType,
                        productCost: 0, // This would normally pull from Product stock
                        priceBeforeTaxAfterDiscount: priceAfterDiscount,
                        priceAfterDiscount: priceAfterDiscount,
                        total: itemTotal,
                        totalAfterDocumentDiscount: totalAfterDiscount,
                        discountApplyRule: false
                    );
                    documentItems.Add(docItem);
                }
                _db.DocumentItems.AddRange(documentItems);

                // 5. Create Payment Record
                var payment = Payment.Create(
                    companyId: companyId,
                    documentId: document.Id,
                    paymentTypeId: req.PaymentTypeId,
                    amount: req.AmountPaid,
                    userId: userId
                );
                _db.Payments.Add(payment);

                // 6. Clean up: Delete the temporary POS Order to save space!
                _db.PosOrderItems.RemoveRange(posOrderItems);
                _db.PosOrders.Remove(posOrder);

                // 7. Commit to Database
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();

                return document;
            }
            catch (Exception)
            {
                // If anything fails, undo EVERYTHING.
                await transaction.RollbackAsync();
                throw;
            }
        }
    }
}