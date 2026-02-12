using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.WarehousesQuery
{
    public class GetAllWarehousesQuery : IRequest<List<WarehouseDto>>
    {
        public class GetAllWarehousesQueryHandler : IRequestHandler<GetAllWarehousesQuery, List<WarehouseDto>>
        {
            private readonly WarehouseRepository _warehouseRepository;
            public GetAllWarehousesQueryHandler(WarehouseRepository warehouseRepository)
            {
                _warehouseRepository = warehouseRepository;
            }
            public async Task<List<WarehouseDto>> Handle(GetAllWarehousesQuery request, CancellationToken cancellationToken)
            {
                var dto = await _warehouseRepository.GetAllWarehousesAsync();
                return dto.Select(MapperWarehouse.MapToWarehouses).ToList();
            }
        }
    }
}
