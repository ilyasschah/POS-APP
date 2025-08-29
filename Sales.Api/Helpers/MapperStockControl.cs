// FILE: Sales.Api.Helpers\MapperStockControl.cs

using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers;

public static class MapperStockControl
{
    public static StockControlDto MapToStockControlDto(StockControl entity)
    {
        return new StockControlDto
        {
            Id = entity.Id,
            ProductId = entity.ProductId,
            ProductName = entity.Product?.Name ?? "N/A",
            CustomerId = entity.CustomerId,
            CustomerName = entity.Customer?.Name ?? "N/A",
            ReorderPoint = entity.ReorderPoint,
            PreferredQuantity = entity.PreferredQuantity,
            IsLowStockWarningEnabled = entity.IsLowStockWarningEnabled,
            LowStockWarningQuantity = entity.LowStockWarningQuantity
        };
    }
}
