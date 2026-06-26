using Api.Commands.PosOrderCommands;
using Api.Commands.PosOrderCommands.Add;
using Api.Commands.PosOrderCommands.Delete;
using Api.Commands.PosOrderItemCommands.Add;
using Api.Constants;
using Api.Models;
using FluentValidation;
using MediatR;

namespace Api.Commands.PosOrderCommands.BatchSync
{
    public class BatchSyncPosOrdersCommand : IRequest<BatchSyncPosOrdersResponse>
    {
        public BatchSyncPosOrdersRequest Request { get; }
        public int CompanyId { get; }

        public BatchSyncPosOrdersCommand(BatchSyncPosOrdersRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class Validator : AbstractValidator<BatchSyncPosOrdersCommand>
        {
            public const int MaxBatchSize = 500;

            public Validator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0);
                RuleFor(x => x.Request.Orders)
                    .NotNull()
                    .Must(o => o.Count > 0).WithMessage("Batch must contain at least one order.")
                    .Must(o => o.Count <= MaxBatchSize).WithMessage($"Batch exceeds max size of {MaxBatchSize}.");
                RuleForEach(x => x.Request.Orders)
                    .ChildRules(item =>
                    {
                        item.RuleFor(i => i.LocalId).NotEmpty().WithMessage("LocalId is required for every batch item.");
                        item.RuleFor(i => i.Order).NotNull();
                    });
            }
        }

        public class Handler : IRequestHandler<BatchSyncPosOrdersCommand, BatchSyncPosOrdersResponse>
        {
            private readonly IMediator _mediator;
            private readonly ILogger<Handler> _logger;

            public Handler(IMediator mediator, ILogger<Handler> logger)
            {
                _mediator = mediator;
                _logger = logger;
            }

            public async Task<BatchSyncPosOrdersResponse> Handle(
                BatchSyncPosOrdersCommand command,
                CancellationToken cancellationToken)
            {
                var response = new BatchSyncPosOrdersResponse();

                // Deliberately NO outer transaction wrapping the loop. Per the
                // offline-first plan: one bad order (e.g. stale product reference,
                // out-of-stock) must not roll back the 49 valid orders the device
                // has been holding while offline. Each call below has its own
                // transactional scope inside its handler.
                foreach (var item in command.Request.Orders)
                {
                    try
                    {
                        if (item.ExistingServerId.HasValue)
                        {
                            // ── Complete an existing open order that was checked
                            // out offline. Call Checkout on the known server order
                            // instead of creating a duplicate. ──────────────────
                            var checkoutRequest = new CheckoutPosOrderRequest
                            {
                                PosOrderId    = item.ExistingServerId.Value,
                                PaymentTypeId = item.PaymentTypeId
                                    ?? throw new InvalidOperationException(
                                        $"PaymentTypeId is required when ExistingServerId is set (localId={item.LocalId})."),
                                AmountPaid    = item.AmountPaid ?? item.OrderTotal,
                                GrandTotal    = item.OrderTotal,
                                DocumentTypeId = DocumentTypeConstants.Sales,
                                WarehouseId   = item.Order.WarehouseId,
                                OrderNumber   = item.Order.Number,
                                ClientDocumentNumber = item.ClientDocumentNumber,
                                Discounts = item.Discounts,
                                Items = item.Items.Select(i => new CheckoutItemDto
                                {
                                    ProductId                   = i.ProductId,
                                    PriceBeforeTaxAfterDiscount = i.Price - i.Discount,
                                    PriceAfterDiscount          = i.Price - i.Discount,
                                    Total                       = (i.Price - i.Discount) * i.Quantity,
                                    TotalAfterDocumentDiscount  = (i.Price - i.Discount) * i.Quantity,
                                    Taxes = i.Taxes.Select(t => new CheckoutItemTaxDto
                                    {
                                        TaxId  = t.TaxId,
                                        Amount = t.Amount,
                                    }).ToList(),
                                }).ToList(),
                            };

                            var documentId = await _mediator.Send(
                                new CheckoutPosOrderCommand(
                                    command.CompanyId,
                                    item.Order.UserId,
                                    checkoutRequest),
                                cancellationToken);

                            response.Results.Add(new BatchSyncResult
                            {
                                LocalId  = item.LocalId,
                                // Return the Document.Id so the Flutter client can
                                // stamp its local Document row's serverId.
                                ServerId = documentId,
                                Success  = true,
                            });
                            continue;
                        }

                        // ── New order: create header then add items ────────────
                        // 1. Create the order header
                        var createdOrder = await _mediator.Send(
                            new CreatePosOrderCommand(item.Order, command.CompanyId),
                            cancellationToken);

                        // 2. Add line items (stamps PosOrderId, runs inventory delta,
                        //    syncs taxes, updates the order total).
                        var warnings = new List<string>();
                        if (item.Items.Any())
                        {
                            foreach (var lineItem in item.Items)
                            {
                                lineItem.PosOrderId = createdOrder.Id;
                            }

                            var itemsResult = await _mediator.Send(
                                new BulkAddPosOrderItemsCommand(
                                    command.CompanyId,
                                    item.Order.WarehouseId,
                                    item.OrderTotal,
                                    item.Items,
                                    // Offline sale already happened — never block the
                                    // replay on current stock; let inventory go negative.
                                    allowNegativeStock: true),
                                cancellationToken);

                            if (!itemsResult.Success)
                            {
                                // Compensate: the header was created in step 1 but its
                                // items failed (e.g. out of stock). Leaving it orphans an
                                // empty order that gets pulled back as a ghost "open order"
                                // with a total but no items. Delete it so a rejected offline
                                // sale leaves nothing behind on the server.
                                try
                                {
                                    await _mediator.Send(
                                        new DeletePosOrderCommand(
                                            createdOrder.Id,
                                            command.CompanyId,
                                            item.Order.WarehouseId),
                                        cancellationToken);
                                }
                                catch (Exception delEx)
                                {
                                    _logger.LogWarning(delEx,
                                        "BatchSync: could not clean up orphan header {OrderId} for {LocalId}",
                                        createdOrder.Id, item.LocalId);
                                }

                                response.Results.Add(new BatchSyncResult
                                {
                                    LocalId = item.LocalId,
                                    ServerId = null, // header removed — nothing to link
                                    Success = false,
                                    Error = itemsResult.Message ?? "Items failed to save.",
                                });
                                continue;
                            }

                            warnings = itemsResult.Warnings ?? new List<string>();
                        }

                        // 3. Checkout: create Document + Payment and remove the PosOrder.
                        //    Only runs when the offline order was paid (PaymentTypeId set).
                        //    Open/saved orders (no PaymentTypeId) stay as PosOrders so
                        //    they show up in the open-orders list on other devices.
                        int resultId = createdOrder.Id; // fallback: PosOrder id if not paid

                        if (item.PaymentTypeId.HasValue)
                        {
                            var checkoutRequest = new CheckoutPosOrderRequest
                            {
                                PosOrderId     = createdOrder.Id,
                                PaymentTypeId  = item.PaymentTypeId.Value,
                                AmountPaid     = item.AmountPaid ?? item.OrderTotal,
                                GrandTotal     = item.OrderTotal,
                                DocumentTypeId = DocumentTypeConstants.Sales,
                                WarehouseId    = item.Order.WarehouseId,
                                OrderNumber    = item.Order.Number,
                                ClientDocumentNumber = item.ClientDocumentNumber,
                                Discounts = item.Discounts,
                                Items = item.Items.Select(i => new CheckoutItemDto
                                {
                                    ProductId                   = i.ProductId,
                                    PriceBeforeTaxAfterDiscount = i.Price - i.Discount,
                                    PriceAfterDiscount          = i.Price - i.Discount,
                                    Total                       = (i.Price - i.Discount) * i.Quantity,
                                    TotalAfterDocumentDiscount  = (i.Price - i.Discount) * i.Quantity,
                                    Taxes = i.Taxes.Select(t => new CheckoutItemTaxDto
                                    {
                                        TaxId  = t.TaxId,
                                        Amount = t.Amount,
                                    }).ToList(),
                                }).ToList(),
                            };

                            // Returns Document.Id so the client can stamp its local
                            // Document row's serverId for linking history records.
                            resultId = await _mediator.Send(
                                new CheckoutPosOrderCommand(
                                    command.CompanyId,
                                    item.Order.UserId,
                                    checkoutRequest),
                                cancellationToken);
                        }

                        response.Results.Add(new BatchSyncResult
                        {
                            LocalId  = item.LocalId,
                            ServerId = resultId,
                            Success  = true,
                            Warnings = warnings,
                        });
                    }
                    catch (InvalidOperationException ex)
                    {
                        // Business-rule failures (out-of-stock, deleted product, etc.)
                        _logger.LogWarning(ex, "BatchSync order {LocalId} rejected: {Message}", item.LocalId, ex.Message);
                        response.Results.Add(new BatchSyncResult
                        {
                            LocalId = item.LocalId,
                            Success = false,
                            Error = ex.Message,
                        });
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "BatchSync order {LocalId} failed unexpectedly", item.LocalId);
                        response.Results.Add(new BatchSyncResult
                        {
                            LocalId = item.LocalId,
                            Success = false,
                            Error = "Server error while syncing this order.",
                        });
                    }
                }

                return response;
            }
        }
    }
}
