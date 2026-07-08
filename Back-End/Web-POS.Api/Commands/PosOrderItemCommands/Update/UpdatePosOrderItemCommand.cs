using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderItemCommands.Update
{
    public class UpdatePosOrderItemCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public UpdatePosOrderItemRequest Request { get; set; }

        public UpdatePosOrderItemCommand(int companyId, UpdatePosOrderItemRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }
        public class UpdatePosOrderItemCommandValidator : AbstractValidator<UpdatePosOrderItemCommand>
        {
            public UpdatePosOrderItemCommandValidator()
            {
                RuleFor(x => x.Request.Id)
                    .GreaterThan(0).WithMessage("Item ID must be valid.");

                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(x => x.Request.Quantity)
                    .GreaterThan(0).WithMessage("Quantity must be greater than zero.");

                RuleFor(x => x.Request.Price)
                    .GreaterThanOrEqualTo(0).WithMessage("Price cannot be negative.");
            }
        }

        // --- HANDLER ---
        public class UpdatePosOrderItemCommandHandler : IRequestHandler<UpdatePosOrderItemCommand, bool>
        {
            private readonly PosOrderItemService _service;

            public UpdatePosOrderItemCommandHandler(PosOrderItemService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdatePosOrderItemCommand command, CancellationToken cancellationToken)
            {
                return await _service.Update(command.CompanyId, command.Request);
            }
        }
    }
}