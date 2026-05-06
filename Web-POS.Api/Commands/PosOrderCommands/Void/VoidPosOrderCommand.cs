using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.PosOrderCommands.Void
{
    public class VoidPosOrderCommand : IRequest<bool>
    {
        public int PosOrderId { get; set; }
        public int CompanyId { get; set; }
        public int WarehouseId { get; set; }
        public int DocumentTypeId { get; set; }

        public VoidPosOrderCommand(int posOrderId, int companyId, int warehouseId, int documentTypeId)
        {
            PosOrderId = posOrderId;
            CompanyId = companyId;
            WarehouseId = warehouseId;
            DocumentTypeId = documentTypeId;
        }

        public class VoidPosOrderCommandValidator : AbstractValidator<VoidPosOrderCommand>
        {
            public VoidPosOrderCommandValidator()
            {
                RuleFor(x => x.PosOrderId).GreaterThan(0).WithMessage("Order ID must be valid.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
                RuleFor(x => x.WarehouseId).GreaterThan(0).WithMessage("Warehouse ID must be valid.");
                RuleFor(x => x.DocumentTypeId).GreaterThan(0).WithMessage("Document Type ID must be valid.");
            }
        }

        public class VoidPosOrderCommandHandler : IRequestHandler<VoidPosOrderCommand, bool>
        {
            private readonly PosOrderVoidService _service;

            public VoidPosOrderCommandHandler(PosOrderVoidService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(VoidPosOrderCommand command, CancellationToken cancellationToken)
            {
                return await _service.VoidAsync(
                    command.CompanyId,
                    command.PosOrderId,
                    command.WarehouseId,
                    command.DocumentTypeId
                );
            }
        }
    }
}
