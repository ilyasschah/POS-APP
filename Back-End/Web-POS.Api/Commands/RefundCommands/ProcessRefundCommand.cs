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
        private readonly ILogger<ProcessRefundCommandHandler> _logger;

        public ProcessRefundCommandHandler(
            AppDbContext db,
            DocumentsCounterRepository counterRepo,
            ILogger<ProcessRefundCommandHandler> logger)
        {
            _db = db;
            _counterRepo = counterRepo;
            _logger = logger;
        }

        /// Server fallback refund number (YY-220-NNNNNN). Used only when the
        /// client did NOT send a device-local number — offline-first clients
        /// always do, so this is the online/legacy path.
        private async Task<string> GenerateServerRefundNumberAsync(int companyId)
        {
            string yy         = DateTime.UtcNow.ToString("yy");
            string counterKey = $"DOC_{yy}_{DocumentTypeConstants.RefundCode}_{companyId}";
            var counter       = await _counterRepo.GetByNameAsync(counterKey, trackEntity: true);
            int nextValue;
            if (counter == null)
            {
                nextValue = 1;
                await _counterRepo.AddAsync(
                    DocumentsCounter.Create(counterKey, nextValue, companyId));
            }
            else
            {
                nextValue = counter.Value + 1;
                counter.UpdateValue(nextValue);
                await _counterRepo.UpdateAsync(counter);
            }
            return $"{yy}-{DocumentTypeConstants.RefundCode}-{nextValue.ToString().PadLeft(6, '0')}";
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

                    // Idempotency guard. Offline clients issue a device-local refund
                    // number (ClientDocumentNumber) and re-send the SAME payload when a
                    // push is retried after an ambiguous failure (a response lost after
                    // the server already committed, a 5xx, a queued re-push). If a refund
                    // with that number already exists, return it instead of creating a
                    // second one — without this, the retry double-reverses stock and
                    // writes a second negative payment (a real double-refund of money).
                    if (!string.IsNullOrWhiteSpace(req.ClientDocumentNumber))
                    {
                        var clientNumber = req.ClientDocumentNumber.Trim();
                        var existing = await _db.Documents
                            .AsNoTracking()
                            .FirstOrDefaultAsync(
                                d => d.Number == clientNumber
                                  && d.CompanyId == command.CompanyId
                                  && d.DocumentTypeId == DocumentTypeConstants.Refund,
                                cancellationToken);
                        if (existing != null)
                        {
                            await tx.CommitAsync(cancellationToken);
                            return new ProcessRefundResponse
                            {
                                RefundDocumentNumber = existing.Number ?? clientNumber,
                                TotalRefunded        = existing.Total,
                            };
                        }
                    }

                    if (req.IsBlind)
                    {
                        var blindResult = await HandleBlindRefundAsync(command, req, cancellationToken);
                        await tx.CommitAsync(cancellationToken);
                        return blindResult;
                    }

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

                    // 6. Refund document number. Offline-first clients send a
                    //    device-local number (e.g. CAISSE1-220-000012) we keep
                    //    verbatim; otherwise fall back to the server sequence.
                    string refundNumber = !string.IsNullOrWhiteSpace(req.ClientDocumentNumber)
                        ? req.ClientDocumentNumber.Trim()
                        : await GenerateServerRefundNumberAsync(command.CompanyId);

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
                        orderNumber:             originalDoc.OrderNumber,
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

        /// Blind return — no original receipt to verify against. A manager
        /// authorised it at the till; items + prices come from the request.
        /// Runs inside the caller's transaction (does not commit).
        private async Task<ProcessRefundResponse> HandleBlindRefundAsync(
            ProcessRefundCommand command,
            ProcessRefundRequest req,
            CancellationToken cancellationToken)
        {
            if (!req.Items.Any())
                throw new InvalidOperationException("A blind return needs at least one item.");

            // Product catalogue (for IsService flag → skip stock reversal on services).
            var productIds = req.Items.Select(i => i.ProductId).Distinct().ToList();
            var products = await _db.Products
                .Where(p => productIds.Contains(p.Id) && p.CompanyId == command.CompanyId)
                .ToDictionaryAsync(p => p.Id, p => p, cancellationToken);

            decimal totalRefunded = req.Items.Sum(i => (i.Price ?? 0m) * i.Quantity);
            if (totalRefunded <= 0)
                throw new InvalidOperationException("Blind return total must be greater than zero.");

            // Same numbering rule as a verified refund: keep the client's
            // device-local 220 number, else fall back to the server sequence.
            string refundNumber = !string.IsNullOrWhiteSpace(req.ClientDocumentNumber)
                ? req.ClientDocumentNumber.Trim()
                : await GenerateServerRefundNumberAsync(command.CompanyId);

            // Resolve a warehouse: the request's, else any belonging to the company.
            int warehouseId = req.WarehouseId > 0
                ? req.WarehouseId
                : await _db.Warehouses.AsNoTracking()
                    .Where(w => w.CompanyId == command.CompanyId)
                    .Select(w => (int?)w.Id)
                    .FirstOrDefaultAsync(cancellationToken)
                  ?? throw new InvalidOperationException(
                      $"No warehouse available for blind return in company {command.CompanyId}.");

            // The customer's claimed paper-receipt number, or a BLIND marker so
            // these are auditable/searchable as unverified returns.
            string referenceNumber = string.IsNullOrWhiteSpace(req.OriginalDocumentNumber)
                ? "BLIND"
                : req.OriginalDocumentNumber.Trim();

            _logger.LogWarning(
                "BLIND REFUND {RefundNumber} (company {CompanyId}) authorised by manager {ApprovedBy}, " +
                "cashier {UserId}, total {Total}, reference '{Reference}'.",
                refundNumber, command.CompanyId, req.ApprovedByUserId, command.UserId,
                totalRefunded, referenceNumber);

            var refundDoc = Document.Create(
                number:                  refundNumber,
                userId:                  command.UserId,
                companyId:               command.CompanyId,
                documentTypeId:          DocumentTypeConstants.Refund,
                warehouseId:             warehouseId,
                total:                   totalRefunded,
                customerId:              null,
                referenceDocumentNumber: referenceNumber,
                paidStatus:              1
            );
            _db.Documents.Add(refundDoc);
            await _db.SaveChangesAsync(cancellationToken);

            foreach (var ri in req.Items)
            {
                var product   = products.GetValueOrDefault(ri.ProductId);
                var unitPrice = ri.Price ?? 0m;
                var lineTotal = unitPrice * ri.Quantity;

                var docItem = DocumentItem.Create(
                    companyId:                   command.CompanyId,
                    documentId:                  refundDoc.Id,
                    productId:                   ri.ProductId,
                    quantity:                    ri.Quantity,
                    expectedQuantity:            ri.Quantity,
                    priceBeforeTax:              unitPrice,
                    price:                       unitPrice,
                    discount:                    0,
                    discountType:                0,
                    productCost:                 product?.Cost ?? 0,
                    priceBeforeTaxAfterDiscount: unitPrice,
                    priceAfterDiscount:          unitPrice,
                    total:                       lineTotal,
                    totalAfterDocumentDiscount:  lineTotal,
                    discountApplyRule:           false
                );
                _db.DocumentItems.Add(docItem);
                await _db.SaveChangesAsync(cancellationToken);

                // Return physical goods to stock (non-service products only).
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

            // Negative payment entry (reverses cash in the Z-Report).
            var payment = Payment.Create(
                companyId:     command.CompanyId,
                documentId:    refundDoc.Id,
                paymentTypeId: req.RefundPaymentTypeId,
                amount:        -totalRefunded,
                userId:        command.UserId
            );
            _db.Payments.Add(payment);
            await _db.SaveChangesAsync(cancellationToken);

            return new ProcessRefundResponse
            {
                RefundDocumentNumber = refundNumber,
                TotalRefunded        = totalRefunded,
            };
        }
    }
}
