namespace Api.Models
{
    public class CustomerDiscountDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int CustomerId { get; set; }
        public int Type { get; set; }
        public int Uid { get; set; }
        public decimal Value { get; set; }
    }

    public class CreateCustomerDiscountRequest
    {
        public required int CustomerId { get; set; }
        public required int Type { get; set; }
        public required int Uid { get; set; }
        public required decimal Value { get; set; }
    }

    public class UpdateCustomerDiscountRequest
    {
        public required int Id { get; set; }
        public required int Type { get; set; }
        public required decimal Value { get; set; }
    }
}