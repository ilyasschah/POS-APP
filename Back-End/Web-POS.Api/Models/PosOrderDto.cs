namespace Api.Models
{
    public class PosOrderDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string Number { get; set; } = string.Empty;
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal? Total { get; set; }
        public int? CustomerId { get; set; }
        public string? CustomerName { get; set; }
        public int ServiceType { get; set; }
        public int ServiceStatus { get; set; }
        public int? FloorPlanTableId { get; set; }
        public DateTime? DueDate { get; set; }

        /// <summary>
        /// Number of line items on this order, and the newest line's DateCreated.
        /// Display-only aggregates so a terminal can tell whether ANOTHER terminal
        /// changed the order's contents without fetching every line on every poll
        /// (the POS polls open orders every 20s).
        ///
        /// Total alone is not enough: swapping a product for one at the same price
        /// leaves it unchanged. A swap deletes and re-inserts a row, so
        /// ItemsLastChanged moves; an add/remove moves ItemCount; an in-place
        /// quantity edit moves Total. Together they cover every edit.
        ///
        /// Computed per request — NOT stored, so there is no schema change and no
        /// migration. Null-safe on the client: an older API that omits them simply
        /// falls back to the Total-only check.
        /// </summary>
        public int ItemCount { get; set; }
        public DateTime? ItemsLastChanged { get; set; }
    }

    public class CreatePosOrderRequest
    {
        public required int UserId { get; set; }
        public string? Number { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal? Total { get; set; }
        public int? CustomerId { get; set; }
        public int ServiceType { get; set; }
        public int ServiceStatus { get; set; }
        public int? FloorPlanTableId { get; set; }
        public required int WarehouseId { get; set; }
        public int? BookingId { get; set; }
    }
    public class UpdatePosOrderStatusRequest
    {
        public required int Id { get; set; }
        public required int ServiceStatus { get; set; }
    }
    public class UpdatePosOrderRequest
    {
        public int Id { get; set; } 
        public required int UserId { get; set; }
        public required string Number { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal? Total { get; set; }
        public int? CustomerId { get; set; }
        public int ServiceType { get; set; }
        public int ServiceStatus { get; set; }
        public int? FloorPlanTableId { get; set; }
        public required int WarehouseId { get; set; }
    }

    public class BulkAddPosOrderItemsResponse
    {
        public bool Success { get; set; }
        public List<string> Warnings { get; set; } = new List<string>();
        public string? Message { get; set; }
    }
}