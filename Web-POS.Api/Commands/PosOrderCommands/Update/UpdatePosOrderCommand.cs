using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderCommands.Update
{
    public class UpdatePosOrderCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public UpdatePosOrderRequest Request { get; set; }

        public UpdatePosOrderCommand(UpdatePosOrderRequest request, int companyId)
        {
            CompanyId = companyId;
            Request = request;
        }
        public class UpdatePosOrderCommandValidator : AbstractValidator<UpdatePosOrderCommand>
        {
            public UpdatePosOrderCommandValidator()
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
        public class UpdatePosOrderCommandHandler : IRequestHandler<UpdatePosOrderCommand, bool>
        {
            private readonly PosOrderService _service;

            public UpdatePosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdatePosOrderCommand command, CancellationToken cancellationToken)
            {
                return await _service.Update(command.CompanyId, command.Request);
            }
        }
    }
}