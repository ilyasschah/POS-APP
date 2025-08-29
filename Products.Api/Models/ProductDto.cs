namespace Products.Api.Models
{
    public class ProductDto
    {
        public  string? Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public  decimal? Price { get; set; }
        public  bool? IsTaxInclusivePrice { get; set; }
        public  bool? IsPriceChangeAllowed { get; set; }
        public  bool? IsService { get; set; }
        public  bool? IsUsingDefaultQuantity { get; set; }
        public  bool? IsEnabled { get; set; }
        public string? Description { get; set; }
        public decimal? Cost { get; set; }
        public decimal? Markup { get; set; }
        public byte[]? Image { get; set; }
        public string? Color { get; set; }
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }
        public int? Rank { get; set; }
        public  string? ProductGroupName { get; set; }
        public string? ParentGroupName { get; set; }
        public  string? CurrencyCode { get; set; }
        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }
    }

    public class CreateProductRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public required decimal Price { get; set; }
        public required bool IsTaxInclusivePrice { get; set; } = true;
        public required bool IsPriceChangeAllowed { get; set; } = true;
        public required bool IsService { get; set; } = false;
        public required bool IsUsingDefaultQuantity { get; set; } = true;
        public required bool IsEnabled { get; set; } = true;
        public string? Description { get; set; }
        public required decimal Cost { get; set; }
        public decimal Markup { get; set; }
        public byte[]? Image { get; set; }
        public required string Color { get; set; }
        public int AgeRestriction { get; set; }
        public decimal LastPurchasePrice { get; set; }
        public int Rank { get; set; }
        public int ProductGroupId { get; set; }
        public int CurrencyId { get; set; }
        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }
    }
    public class UpdateProductRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
        public decimal Price { get; set; }
        public decimal Cost { get; set; }
        public string? Description { get; set; }
        public string? Color { get; set; }
        public byte[]? Image { get; set; }
        public int ProductGroupId { get; set; }
        public int CurrencyId { get; set; }
        public bool IsEnabled { get; set; }
        public string? MeasurementUnit { get; set; }
        public int PLU { get; set; }
        public bool IsTaxInclusivePrice { get; set; }
        public bool IsPriceChangeAllowed { get; set; }
        public bool IsService { get; set; }
        public bool IsUsingDefaultQuantity { get; set; }
        public decimal Markup { get; set; }
        public int? AgeRestriction { get; set; }
        public decimal LastPurchasePrice { get; set; }
        public int Rank { get; set; }
    }
}