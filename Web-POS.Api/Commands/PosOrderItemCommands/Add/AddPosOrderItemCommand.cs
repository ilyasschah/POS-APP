using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;
using Api.Helpers;

namespace Api.Commands.PosOrderItemCommand
{
    public class CreatePosOrderItemCommand : IRequest<PosOrderItemDto>
    {
        public int CompanyId { get; set; }
        public CreatePosOrderItemRequest Request { get; set; }

        public CreatePosOrderItemCommand(int companyId, CreatePosOrderItemRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class CreatePosOrderItemCommandValidator : AbstractValidator<CreatePosOrderItemCommand>
        {
            public CreatePosOrderItemCommandValidator()
            {
                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(x => x.Request.PosOrderId)
                    .GreaterThan(0).WithMessage("Order ID is required to add an item.");

                RuleFor(x => x.Request.ProductId)
                    .GreaterThan(0).WithMessage("Product ID is required.");

                RuleFor(x => x.Request.Quantity)
                    .GreaterThan(0).WithMessage("Quantity must be greater than zero.");

                RuleFor(x => x.Request.Price)
                    .GreaterThanOrEqualTo(0).WithMessage("Price cannot be negative.");
            }
        }

        // --- HANDLER ---
        public class CreatePosOrderItemCommandHandler : IRequestHandler<CreatePosOrderItemCommand, PosOrderItemDto>
        {
            private readonly PosOrderItemService _service;

            public CreatePosOrderItemCommandHandler(PosOrderItemService service)
            {
                _service = service;
            }

            public async Task<PosOrderItemDto> Handle(CreatePosOrderItemCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.CompanyId, command.Request);
                return MapperPosOrderItem.MapToPosOrderItemDto(newEntity);
            }
        }
    }
}