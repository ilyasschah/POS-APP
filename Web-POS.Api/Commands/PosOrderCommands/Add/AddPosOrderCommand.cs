using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PosOrderCommands.Add
{
    public class AddPosOrderCommand : IRequest<PosOrderDto>
    {
        public CreatePosOrderRequest Request { get; set; }

        public AddPosOrderCommand(CreatePosOrderRequest request)
        {
            Request = request;
        }

        // Nested Handler
        public class AddPosOrderCommandHandler : IRequestHandler<AddPosOrderCommand, PosOrderDto>
        {
            private readonly PosOrderService _service;

            public AddPosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public async Task<PosOrderDto> Handle(AddPosOrderCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return new PosOrderDto
                {
                    Id = newEntity.Id,
                    UserId = newEntity.UserId,
                    Number = newEntity.Number,
                    Discount = newEntity.Discount,
                    DiscountType = newEntity.DiscountType,
                    Total = newEntity.Total,
                    CustomerId = newEntity.CustomerId
                    // UserName and CustomerName will be null here as they are not loaded on creation
                };
            }
        }

        // Nested Validator
        public class AddPosOrderCommandValidator : AbstractValidator<AddPosOrderCommand>
        {
            public AddPosOrderCommandValidator()
            {
                RuleFor(c => c.Request.Number).NotNull().NotEmpty().WithMessage("Order number is required.");
                RuleFor(c => c.Request.UserId).GreaterThan(0).WithMessage("A valid user is required.");
            }
        }
    }
}