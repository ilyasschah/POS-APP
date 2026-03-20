using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.WarehouseCommands.Add
{
    public class AddWarehouseCommand : IRequest<WarehouseDto>
    {
        public CreateWarehouseRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddWarehouseCommand(CreateWarehouseRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddWarehouseCommandHandler : IRequestHandler<AddWarehouseCommand, WarehouseDto>
        {
            private readonly WarehouseService _warehouseService;

            public AddWarehouseCommandHandler(WarehouseService warehouseService)
            {
                _warehouseService = warehouseService;
            }

            public async Task<WarehouseDto> Handle(AddWarehouseCommand request, CancellationToken cancellationToken)
            {
                return await _warehouseService.CreateAsync(request.Request, request.CompanyId);
            }
        }

        public class AddWarehouseCommandValidator : AbstractValidator<AddWarehouseCommand>
        {
            public AddWarehouseCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Warehouse name is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}