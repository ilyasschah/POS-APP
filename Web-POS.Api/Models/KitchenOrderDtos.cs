namespace Api.Models
{
    /// <summary>
    /// Flat, clean DTO for the Kitchen Display System (KDS).
    /// Contains all order info and its items in one flat object.
    /// </summary>
    public class KitchenOrderDto
    {
        public int Id { get; set; }
        public string Number { get; set; } = string.Empty;
        public int? FloorPlanTableId { get; set; }
        public string? TableName { get; set; }
        public int ServiceType { get; set; }
        public int ServiceStatus { get; set; }
        public List<KitchenOrderItemDto> Items { get; set; } = new();
    }

    public class KitchenOrderItemDto
    {
        public int Id { get; set; }
        public string ProductName { get; set; } = string.Empty;
        public decimal Quantity { get; set; }
        public string? Comment { get; set; }
    }
}
