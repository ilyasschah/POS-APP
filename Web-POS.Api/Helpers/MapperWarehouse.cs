using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperWarehouse
    {
        public static WarehouseDto MapToWarehouseDto(Warehouse entity)
        {
            if (entity == null) return null;

            return new WarehouseDto
            {
                Id = entity.Id,
                Name = entity.Name,
                CompanyName = entity.Company?.Name
            };
        }
    }
}