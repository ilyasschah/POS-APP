namespace Products.Api.Models
{
    public class StockDto
    {
        public int Id { get; set; }
        public decimal? Quantity { get; set; }
        public int WarehouseId { get; set; }
        public string? WarehouseName { get; set; }
        public int ProductionId { get; set; }
        public string? ProductName { get; set; }
        public int CompanyId { get; set; }
    }
    public class CreateStockRequest
    {
        public required int ProductId { get; set; }
        public required decimal Quantity { get; set; }
        public required int WarehouseId { get; set; }
    }
    public class UpdateStockRequest
    {
        public required decimal newQuantity { get; set; }
        public required int newWarehouseId { get; set; }
    }
}
