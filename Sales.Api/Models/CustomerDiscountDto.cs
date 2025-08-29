namespace Sales.Api.Models
{
    public class CustomerDiscountDto
    {
        public string? CustomerName { get; set; }
        public int? Type { get; set; }
        public int? Uid { get; set; }
        public decimal Value { get; set; }
    }
    public class CreateCustomerDiscountRequest
    {
        public int CustomerId { get; set; }
        public int Type { get; set; }
        public int Uid { get; set; }
        public decimal Value { get; set; }
    }
    public class UpdateCustomerDiscountRequest
    {
        public int CustomerId { get; set; }
        public int Type { get; set; }
        public int Uid { get; set; }
        public decimal Value { get; set; }
    }
}
