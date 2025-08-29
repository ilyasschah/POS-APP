namespace Stocks.Api.Models
{
    public class StockDto
    {
        public decimal? Quantity { get; set; }
        public string? WarehouseName { get; set; }
        public string? ProductName { get; set; }
    }
    public class CreateStockRequest
    {
        public required decimal Quantity { get; set; }
        public required int WarehouseId { get; set; }
        public required int ProductId { get; set; }
    }
    public class UpdateStockRequest
    {
        public required decimal Quantity { get; set; }
        public required int WarehouseId { get; set; }
        public required int ProductId { get; set; }
    }
}
