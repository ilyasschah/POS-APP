namespace Api.Models
{
    public class StockDto
    {
        public int Id { get; set; }
        public decimal? Quantity { get; set; }
        public int WarehouseId { get; set; }
        public string? WarehouseName { get; set; }
        public int ProductId { get; set; }
        public string? ProductName { get; set; }
        public int CompanyId { get; set; }
        public string? CompanyName { get; set; }
    }
    public class CreateStockRequest
    {
        public required int ProductId { get; set; }
        public decimal Quantity { get; set; }=  0;
        public required int WarehouseId { get; set; }
    }
    public class UpdateStockRequest
    {
        public required int Id { get; set; }
        public  decimal? newQuantity { get; set; }
        public  int? newWarehouseId { get; set; }
        public int? newProductId { get; set; }
    }
}
