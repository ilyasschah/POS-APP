using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.WarehousesQuery
{
    public class GetWarehouseByIdQuery : IRequest<WarehouseDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetWarehouseByIdQueryHandler : IRequestHandler<GetWarehouseByIdQuery, WarehouseDto?>
    {
        private readonly WarehouseRepository _warehouseRepository;

        public GetWarehouseByIdQueryHandler(WarehouseRepository warehouseRepository)
        {
            _warehouseRepository = warehouseRepository;
        }

        public async Task<WarehouseDto?> Handle(GetWarehouseByIdQuery request, CancellationToken cancellationToken)
        {
            var warehouse = await _warehouseRepository.GetByIdAsync(request.Id, request.CompanyId);
            return warehouse == null ? null : MapperWarehouse.MapToWarehouseDto(warehouse);
        }
    }

    public class GetWarehouseByIdQueryValidator : AbstractValidator<GetWarehouseByIdQuery>
    {
        public GetWarehouseByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Warehouse ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}