namespace Api.Models
{
    public class DocumentItemDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int DocumentId { get; set; }
        public string? DocumentNumber { get; set; }
        public int ProductId { get; set; }
        public string? ProductCode { get; set; }
        public string? ProductName { get; set; }
        public string? MeasurementUnit { get; set; }
        public decimal Quantity { get; set; }
        public decimal ExpectedQuantity { get; set; }
        public decimal PriceBeforeTax { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal ProductCost { get; set; }
        public decimal PriceBeforeTaxAfterDiscount { get; set; }
        public decimal PriceAfterDiscount { get; set; }
        public decimal Total { get; set; }
        public decimal TotalAfterDocumentDiscount { get; set; }
        public bool DiscountApplyRule { get; set; }

        /// The modifier options this line was sold with, snapshotted at the
        /// time of sale. Empty on every line that has none, and on every
        /// document that predates modifiers.
        public List<ModifierSnapshotDto> Modifiers { get; set; } = new();
    }

    public class CreateDocumentItemRequest
    {
        public required int DocumentId { get; set; }
        public required int ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal ExpectedQuantity { get; set; }
        public decimal PriceBeforeTax { get; set; }
        public decimal Price { get; set; }
        public decimal Discount { get; set; }
        public int DiscountType { get; set; }
        public decimal ProductCost { get; set; }
        public bool DiscountApplyRule { get; set; }
    }

    public class UpdateDocumentItemRequest
    {
        public required int Id { get; set; }
        public int? DocumentId { get; set; }
        public int? ProductId { get; set; }
        public decimal? Quantity { get; set; }
        public decimal? ExpectedQuantity { get; set; }
        public decimal? PriceBeforeTax { get; set; }
        public decimal? Price { get; set; }
        public decimal? Discount { get; set; }
        public int? DiscountType { get; set; }
        public decimal? ProductCost { get; set; }
        public bool? DiscountApplyRule { get; set; }
    }
}