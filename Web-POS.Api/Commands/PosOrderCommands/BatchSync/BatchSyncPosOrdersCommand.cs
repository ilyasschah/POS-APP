using Api.Commands.PosOrderCommands.Add;
using Api.Commands.PosOrderItemCommands.Add;
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
                        // 1. Create the order header
                        var createdOrder = await _mediator.Send(
                            new CreatePosOrderCommand(item.Order, command.CompanyId),
                            cancellationToken);

                        // 2. Add line items (stamps PosOrderId, runs inventory delta,
                        //    syncs taxes, updates the order total). If this fails the
                        //    header still exists — accepted V1 behaviour. A follow-up
                        //    can compensate by deleting orphaned empty orders.
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
                                    item.Items),
                                cancellationToken);

                            if (!itemsResult.Success)
                            {
                                response.Results.Add(new BatchSyncResult
                                {
                                    LocalId = item.LocalId,
                                    ServerId = createdOrder.Id, // header still created
                                    Success = false,
                                    Error = itemsResult.Message ?? "Items failed to save.",
                                });
                                continue;
                            }

                            warnings = itemsResult.Warnings ?? new List<string>();
                        }

                        response.Results.Add(new BatchSyncResult
                        {
                            LocalId = item.LocalId,
                            ServerId = createdOrder.Id,
                            Success = true,
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
