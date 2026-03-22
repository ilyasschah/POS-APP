using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperStock_P_Name_W_Name
    {
        public static StockDto MapToStockDetails(Stock stock)
        {
            return new StockDto
            {
                Id = stock.Id,
                Quantity = stock.Quantity,
                ProductId = stock.ProductId,
                ProductName = stock.Product?.Name,
                WarehouseId = stock.WarehouseId,
                WarehouseName = stock.Warehouse?.Name,
                CompanyId = stock.CompanyId,
                CompanyName = stock.Company?.Name
            };
        }
    }
}
