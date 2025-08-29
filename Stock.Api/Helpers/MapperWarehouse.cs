using Stocks.Api.Domain;
using Stocks.Api.Models;

namespace Stocks.Api.Helpers
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
