using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperWarehouse
    {
        public static WarehouseDto MapToWarehouses(Warehouse warehouses)
        {
            return new WarehouseDto
            {
                Name = warehouses.Name
            };
        }
    }
}
