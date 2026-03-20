using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.WarehouseCommands.Update
{
    public class UpdateWarehouseCommand : IRequest<bool>
    {
        public UpdateWarehouseRequest Request { get; set; }
        public int CompanyId { get; set; }
        public UpdateWarehouseCommand(UpdateWarehouseRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }
        public class UpdateWarehouseCommandHandler : IRequestHandler<UpdateWarehouseCommand, bool>
        {
            private readonly WarehouseService _warehouseService;
            public UpdateWarehouseCommandHandler(WarehouseService warehouseService)
            {
                _warehouseService = warehouseService;
            }
            public Task<bool> Handle(UpdateWarehouseCommand request, CancellationToken cancellationToken)
            {
                return _warehouseService.UpdateAsync(request.Request, request.CompanyId);
            }
        }
    }
    public class UpdateWarehouseCommandValidator : AbstractValidator<UpdateWarehouseCommand>
    {
        public UpdateWarehouseCommandValidator()
        {
            RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Warehouse name is required.");
        }
    }
}
