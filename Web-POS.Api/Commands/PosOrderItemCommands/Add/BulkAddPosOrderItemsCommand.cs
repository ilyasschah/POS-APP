using MediatR;
using Api.Domain;
using Api.Models;
using Api.Repository;

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
            private readonly PosOrderItemRepository _repository;

            public BulkAddPosOrderItemsCommandHandler(PosOrderItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<bool> Handle(BulkAddPosOrderItemsCommand command, CancellationToken cancellationToken)
            {
                if (command.Items == null || !command.Items.Any())
                    return false;

                var itemsToSave = new List<PosOrderItem>();

                foreach (var req in command.Items)
                {
                    var item = PosOrderItem.Create(
                        companyId: command.CompanyId,
                        posOrderId: req.PosOrderId,
                        productId: req.ProductId,
                        roundNumber: req.RoundNumber,
                        quantity: req.Quantity,
                        price: req.Price,
                        discount: req.Discount,
                        discountType: req.DiscountType,
                        discountAppliedType: req.DiscountAppliedType,
                        comment: req.Comment,
                        bundle: req.Bundle
                    );
                    itemsToSave.Add(item);
                }
                await _repository.AddRangeAsync(itemsToSave);
                return true;
            }
        }
    }
}