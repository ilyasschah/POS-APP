using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperWarehouse
    {
        public static WarehouseDto MapToWarehouseDto(Warehouse entity)
        {
            return new WarehouseDto
            {
                Id = entity.Id,
                Name = entity.Name,
                CompanyId = entity.CompanyId
            };
        }
    }
}