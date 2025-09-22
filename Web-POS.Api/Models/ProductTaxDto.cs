
namespace Products.Api.Models
{
    public class ProductTaxDto
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; } = string.Empty;
        public int TaxId { get; set; }
        public string TaxName { get; set; } = string.Empty;
        public decimal TaxRate { get; set; }
    }

    public class CreateProductTaxRequest
    {
        public required int ProductId { get; set; }
        public required int TaxId { get; set; }
    }
}