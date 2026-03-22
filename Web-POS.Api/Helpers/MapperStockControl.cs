// FILE: Products.Api.Helpers\MapperStockControl.cs

using Api.Domain;
using Api.Models;

namespace Api.Helpers;

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
