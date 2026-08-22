using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.WarehousesQuery
{
    public class GetWarehouseByName: IRequest<WarehouseDto?>
    {
        public required string Name { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetWarehouseByNameQueryHandler : IRequestHandler<GetWarehouseByName, WarehouseDto?>
    {
        private readonly WarehouseRepository _warehouseRepository;

        public GetWarehouseByNameQueryHandler(WarehouseRepository warehouseRepository)
        {
            _warehouseRepository = warehouseRepository;
        }

        public async Task<WarehouseDto?> Handle(GetWarehouseByName request, CancellationToken cancellationToken)
        {
            var warehouse = await _warehouseRepository.GetByNameAsync(request.Name, request.CompanyId);
            return warehouse == null ? null : MapperWarehouse.MapToWarehouseDto(warehouse);
        }
    }

    public class GetWarehouseByNameQueryValidator : AbstractValidator<GetWarehouseByName>
    {
        public GetWarehouseByNameQueryValidator()
        {
            RuleFor(x => x.Name).NotEmpty().WithMessage("Warehouse name must be provided.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
