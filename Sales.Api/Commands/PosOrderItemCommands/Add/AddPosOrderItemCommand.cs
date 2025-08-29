using FluentValidation;
using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.PosOrderItemCommands.Add
{
    public class AddPosOrderItemCommand : IRequest<PosOrderItemDto>
    {
        public CreatePosOrderItemRequest Request { get; set; }
        public AddPosOrderItemCommand(CreatePosOrderItemRequest createposorderitemRequest)
        {
            Request = createposorderitemRequest;
        }
        public class AddPosOrderItemCommandHandler : IRequestHandler<AddPosOrderItemCommand, PosOrderItemDto>
        {
            private readonly PosOrderItemService _service;

            public AddPosOrderItemCommandHandler(PosOrderItemService service)
            {
                _service = service;
            }
            public async Task<PosOrderItemDto> Handle(AddPosOrderItemCommand command, CancellationToken cancellationToken)
            {
                
                try
                {
                    var newEntity = await _service.CreateAsync(command.Request);
                    return new PosOrderItemDto
                    {
                        PosOrderId = newEntity.PosOrderId,
                        ProductId = newEntity.ProductId,
                        ProductName = newEntity.Product.Name,
                        Quantity = newEntity.Quantity,
                        Price = newEntity.Price,
                        Discount = newEntity.Discount,
                        DiscountType = newEntity.DiscountType,
                        Comment = newEntity.Comment,
                        RoundNumber = newEntity.RoundNumber,
                    };
                }
                catch (Exception)
                {
                    throw;
                }
            }
        }

        public class AddPosOrderItemCommandValidator : AbstractValidator<AddPosOrderItemCommand>
        {
            public AddPosOrderItemCommandValidator()
            {
                RuleFor(c => c.Request.PosOrderId).GreaterThan(0);
                RuleFor(c => c.Request.ProductId).GreaterThan(0);
                RuleFor(c => c.Request.Quantity).GreaterThan(0);
            }
        }
    }
}