using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.WarehousesQuery
{
    public class GetAllWarehousesQuery : IRequest<List<WarehouseDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllWarehousesQueryHandler : IRequestHandler<GetAllWarehousesQuery, List<WarehouseDto>>
        {
            private readonly WarehouseRepository _warehouseRepository;

            public GetAllWarehousesQueryHandler(WarehouseRepository warehouseRepository)
            {
                _warehouseRepository = warehouseRepository;
            }

            public async Task<List<WarehouseDto>> Handle(GetAllWarehousesQuery request, CancellationToken cancellationToken)
            {
                var warehouses = await _warehouseRepository.GetAllAsync(request.CompanyId);

                return warehouses.Select(MapperWarehouse.MapToWarehouseDto).ToList();
            }
        }
    }

    public class GetAllWarehousesQueryValidator : AbstractValidator<GetAllWarehousesQuery>
    {
        public GetAllWarehousesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}