using MediatR;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.WarehousesQuery
{
    public class GetWarehouseByIdQuery : IRequest<WarehouseDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public GetWarehouseByIdQuery(int id)
        {
            Id = id;
        }
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
            var warehouse =  await _warehouseRepository.GetwarehouseByIdAsync(request.Id, request.CompanyId);
            if (warehouse is null)
            {
                return null;
            }
            return new WarehouseDto
            {
                Name = warehouse.Name,
            };
        }
    }
}
