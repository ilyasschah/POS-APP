namespace Products.Api.Models
{
    public class DocumentItemDto
    {
        public int Id { get; set; }
        public int DocumentId { get; set; }
        public string DocumentNumber { get; set; }
        public int ProductId { get; set; }
        public string? ProductName { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal TaxRate { get; set; }
        public decimal ProductCost { get; set; }
        public decimal PriceBeforeTaxAfterDiscount { get; set; }
        public decimal TotalAfterDocumentDiscount { get; set; }
        public decimal PriceAfterDiscount { get; set; }
        public decimal Total { get; set; }
        public DateTime DateCreated { get; set; }
        public DateTime DateUpdated { get; set; }
    }
    public class CreateDocumentItemRequest
    {
        public int Id { get; set; }
        public int DocumentId { get; set; }
        public int ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal TaxRate { get; set; }
        public decimal ProductCost { get; set; }
        public decimal PriceBeforeTax { get; set; }
        public decimal PriceBeforeTaxAfterDiscount { get; set; }
        public decimal TotalAfterDocumentDiscount { get; set; }
        public decimal PriceAfterDiscount { get; set; }
        public decimal Total { get; set; }
        public bool DiscountApplyRule { get; set; }
        public DateTime DateCreated { get; set; } = DateTime.UtcNow;
        public DateTime DateUpdated { get; set; } = DateTime.UtcNow;
    }
    public class UpdateDocumentItemRequest
    {
        public int Id { get; set; }
        public decimal NewQuantity { get; set; }
        public DateTime DateUpdated { get; set; } = DateTime.UtcNow;
    }
}
