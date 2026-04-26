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
        //public int? BookingId { get; set; }
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
    }
}