using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.WarehouseCommands.Add
{
    public class AddWarehousecommand : IRequest<bool>
    {
        public CreateWarehouseRequest Request { get; set; }
        public int CompanyId { get; set; }
        public AddWarehousecommand(CreateWarehouseRequest request, int companyId)
        {
            Request = request ;
            CompanyId = companyId;
        }
        public class AddWarehousecommandHandler : IRequestHandler<AddWarehousecommand, bool>
        {
            private readonly WarehouseService _warehouseService;
            public AddWarehousecommandHandler(WarehouseService warehouseService)
            {
                _warehouseService = warehouseService;
            }
            public async Task<bool> Handle(AddWarehousecommand request, CancellationToken cancellationToken)
            {
               try
                    {
                      return await _warehouseService.Create(request.Request.Name, request.CompanyId);
                }
                catch (Exception)
                {
                     throw;
                }
            }
        }
        public class AddWarehousecommandValidator : AbstractValidator<AddWarehousecommand>
        {
            public AddWarehousecommandValidator()
            {
                RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Warehouse name is required.");
            }
        }
    }
}

