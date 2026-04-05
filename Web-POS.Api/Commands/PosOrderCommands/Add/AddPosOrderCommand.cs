using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;
using Api.Helpers;

namespace Api.Commands.PosOrderCommand
{
    public class CreatePosOrderCommand : IRequest<PosOrderDto>
    {
        public int CompanyId { get; set; }
        public CreatePosOrderRequest Request { get; set; }

        public CreatePosOrderCommand(int companyId, CreatePosOrderRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        // --- VALIDATOR ---
        public class CreatePosOrderCommandValidator : AbstractValidator<CreatePosOrderCommand>
        {
            public CreatePosOrderCommandValidator()
            {
                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(x => x.Request.UserId)
                    .GreaterThan(0).WithMessage("User ID must be valid.");

                RuleFor(x => x.Request.Number)
                    .NotEmpty().WithMessage("Order Number is required.");

                RuleFor(x => x.Request.Discount)
                    .GreaterThanOrEqualTo(0).WithMessage("Discount cannot be negative.");
            }
        }

        // --- HANDLER ---
        public class CreatePosOrderCommandHandler : IRequestHandler<CreatePosOrderCommand, PosOrderDto>
        {
            private readonly PosOrderService _service;

            public CreatePosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public async Task<PosOrderDto> Handle(CreatePosOrderCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.CompanyId, command.Request);
                return MapperPosOrder.MapToPosOrderDto(newEntity);
            }
        }
    }
}