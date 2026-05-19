using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Models;
using Api.Repository;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.RefundCommands
{
    public class ProcessRefundCommand : IRequest<ProcessRefundResponse>
    {
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public ProcessRefundRequest Request { get; set; } = default!;
    }

    public class ProcessRefundCommandHandler
        : IRequestHandler<ProcessRefundCommand, ProcessRefundResponse>
    {
        private readonly AppDbContext _db;
        private readonly DocumentsCounterRepository _counterRepo;

        public ProcessRefundCommandHandler(AppDbContext db, DocumentsCounterRepository counterRepo)
        {
            _db = db;
            _counterRepo = counterRepo;
        }

        public async Task<ProcessRefundResponse> Handle(
            ProcessRefundCommand command,
            CancellationToken cancellationToken)
        {
            var strategy = _db.Database.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
                try
                {
                    var req = command.Request;

                    // 1. Locate original sales document
                    var originalDoc = await _db.Documents
                        .AsNoTracking()
                        .FirstOrDefaultAsync(
                            d => d.Number == req.OriginalDocumentNumber
                              && d.CompanyId == command.CompanyId,
                            cancellationToken)
                        ?? throw new InvalidOperationException(
                            $"Receipt '{req.OriginalDocumentNumber}' not found.");

                    // 2. Fetch all original line items
                    var originalItems = await _db.DocumentItems
                        .AsNoTracking()
                        .Where(di => di.DocumentId == originalDoc.Id
                                  && di.CompanyId == command.CompanyId)
                        .ToListAsync(cancellationToken);

                    if (!originalItems.Any())
                        throw new InvalidOperationException("Original document has no items.");

                    // 3. Determine which items to refund
                    //    Empty Items list → refund entire receipt
                    var refundItems = req.Items.Any()
                        ? req.Items
                        : originalItems
                            .Select(i => new RefundItemRequest
                            {
                                ProductId = i.ProductId,
                                Quantity  = i.Quantity,
                            })
                            .ToList();

                    // 4. Load product catalogue (for IsService flag)
                    var productIds = refundItems.Select(i => i.ProductId).Distinct().ToList();
                    var products = await _db.Products
                        .Where(p => productIds.Contains(p.Id) && p.CompanyId == command.CompanyId)
                        .ToDictionaryAsync(p => p.Id, p => p, cancellationToken);

                    // 5. Calculate total to refund
                    decimal totalRefunded = 0;
                    foreach (var ri in refundItems)
                    {
                        var orig = originalItems.FirstOrDefault(i => i.ProductId == ri.ProductId)
                            ?? throw new InvalidOperationException(
                                $"Product {ri.ProductId} was not in the original receipt.");
                        totalRefunded += orig.PriceBeforeTaxAfterDiscount * ri.Quantity;
                    }

                    // 6. Generate sequential refund document number (220 counter)
                    string yy         = DateTime.UtcNow.ToString("yy");
                    string counterKey = $"DOC_{yy}_{DocumentTypeConstants.RefundCode}_{command.CompanyId}";
                    var counter       = await _counterRepo.GetByNameAsync(counterKey, trackEntity: true);
                    int nextValue;
                    if (counter == null)
                    {
                        nextValue = 1;
                        await _counterRepo.AddAsync(
                            DocumentsCounter.Create(counterKey, nextValue, command.CompanyId));
                    }
                    else
                    {
                        nextValue = counter.Value + 1;
                        counter.UpdateValue(nextValue);
                        await _counterRepo.UpdateAsync(counter);
                    }
                    string refundNumber = $"{yy}-{DocumentTypeConstants.RefundCode}-{nextValue.ToString().PadLeft(6, '0')}";

                    // 7. Create the refund Document
                    int warehouseId = req.WarehouseId > 0
                        ? req.WarehouseId
                        : originalDoc.WarehouseId;

                    var refundDoc = Document.Create(
                        number:                  refundNumber,
                        userId:                  command.UserId,
                        companyId:               command.CompanyId,
                        documentTypeId:          DocumentTypeConstants.Refund,
                        warehouseId:             warehouseId,
                        total:                   totalRefunded,
                        customerId:              originalDoc.CustomerId,
                        referenceDocumentNumber: req.OriginalDocumentNumber,
                        paidStatus:              1
                    );
                    _db.Documents.Add(refundDoc);
                    await _db.SaveChangesAsync(cancellationToken);

                    // 8. Create DocumentItems + explicit stock reversal
                    foreach (var ri in refundItems)
                    {
                        var orig    = originalItems.First(i => i.ProductId == ri.ProductId);
                        var product = products.GetValueOrDefault(ri.ProductId);

                        var lineTotal = orig.PriceBeforeTaxAfterDiscount * ri.Quantity;

                        var docItem = DocumentItem.Create(
                            companyId:                  command.CompanyId,
                            documentId:                 refundDoc.Id,
                            productId:                  ri.ProductId,
                            quantity:                   ri.Quantity,
                            expectedQuantity:           ri.Quantity,
                            priceBeforeTax:             orig.PriceBeforeTax,
                            price:                      orig.Price,
                            discount:                   orig.Discount,
                            discountType:               orig.DiscountType,
                            productCost:                orig.ProductCost,
                            priceBeforeTaxAfterDiscount: orig.PriceBeforeTaxAfterDiscount,
                            priceAfterDiscount:         orig.PriceAfterDiscount,
                            total:                      lineTotal,
                            totalAfterDocumentDiscount: lineTotal,
                            discountApplyRule:          false
                        );
                        _db.DocumentItems.Add(docItem);
                        await _db.SaveChangesAsync(cancellationToken);

                        // Explicit stock reversal for non-service products.
                        // Note: if DocumentItem_Insert_Trigger already handles stock direction
                        // for DocumentType 220, remove this block to avoid double-counting.
                        if (product != null && !product.IsService)
                        {
                            var stock = await _db.Stocks.FirstOrDefaultAsync(
                                s => s.ProductId   == ri.ProductId
                                  && s.WarehouseId == warehouseId
                                  && s.CompanyId   == command.CompanyId,
                                cancellationToken);

                            if (stock != null)
                            {
                                stock.UpdateDetails(
                                    stock.Quantity + ri.Quantity,
                                    stock.WarehouseId,
                                    stock.ProductId);
                                _db.Stocks.Update(stock);
                            }
                        }
                    }

                    // 9. Negative payment entry (reverses the original sale in Z-Report)
                    var payment = Payment.Create(
                        companyId:     command.CompanyId,
                        documentId:    refundDoc.Id,
                        paymentTypeId: req.RefundPaymentTypeId,
                        amount:        -totalRefunded,
                        userId:        command.UserId
                    );
                    _db.Payments.Add(payment);

                    await _db.SaveChangesAsync(cancellationToken);
                    await tx.CommitAsync(cancellationToken);

                    return new ProcessRefundResponse
                    {
                        RefundDocumentNumber = refundNumber,
                        TotalRefunded        = totalRefunded,
                    };
                }
                catch
                {
                    await tx.RollbackAsync(cancellationToken);
                    throw;
                }
            });
        }
    }
}
