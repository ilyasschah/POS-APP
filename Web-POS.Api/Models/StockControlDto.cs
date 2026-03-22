// FILE: Products.Api.Models\StockControlDto.cs

namespace Api.Models;

public class StockControlDto
{
    public int Id { get; set; }
    public int ProductId { get; set; }
    public string ProductName { get; set; }
    public int? CustomerId { get; set; }
    public string? CustomerName { get; set; }
    public decimal ReorderPoint { get; set; }
    public decimal PreferredQuantity { get; set; }
    public bool IsLowStockWarningEnabled { get; set; }
    public decimal LowStockWarningQuantity { get; set; }
}

public class CreateStockControlRequest
{
    public required int ProductId { get; set; }
    public int? CustomerId { get; set; }
    public decimal ReorderPoint { get; set; } = 0;
    public decimal PreferredQuantity { get; set; } = 0;
    public bool IsLowStockWarningEnabled { get; set; } = true;
    public decimal LowStockWarningQuantity { get; set; } = 0;
}

public class UpdateStockControlRequest
{
    public required int Id { get; set; }
    public int? CustomerId { get; set; }
    public decimal ReorderPoint { get; set; }
    public decimal PreferredQuantity { get; set; }
    public bool IsLowStockWarningEnabled { get; set; }
    public decimal LowStockWarningQuantity { get; set; }
}
