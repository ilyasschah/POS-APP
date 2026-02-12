using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperStock_P_Name_W_Name
    {
        public static StockDto MapToStockDetails(Stock stock)
        {
            return new StockDto
            {
                Id = stock.Id,
                Quantity = stock.Quantity,
                ProductName = stock.Product.Name,
                WarehouseName = stock.Warehouse.Name,
                CompanyId = stock.CompanyId
            };
        }
    }
    public class MapperStock
    {
        public static StockDto MapToStock(Stock stock)
        {
            return new StockDto
            {
                Id = stock.Id,
                Quantity = stock.Quantity,
                ProductName = stock.Product.Name,
                WarehouseName = stock.Warehouse.Name,
                CompanyId = stock.CompanyId
            };
        }
    }
}
