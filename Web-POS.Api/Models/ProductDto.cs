using System;

namespace Products.Api.Models
{
    public class ProductDto
    {
        public int Id { get; set; }
        public int? ProductGroupId { get; set; }
        public string Name { get; set; } = default!;
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public decimal Price { get; set; }
        public bool IsTaxInclusivePrice { get; set; }
        public int? CurrencyId { get; set; }
        public bool IsPriceChangeAllowed { get; set; }
        public bool IsService { get; set; }
        public bool IsUsingDefaultQuantity { get; set; }
        public bool IsEnabled { get; set; }
        public string? Description { get; set; }
        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }
        public decimal Cost { get; set; }
        public decimal? Markup { get; set; }
        public byte[]? Image { get; set; }
        public string Color { get; set; } = "Transparent";
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }
        public int? Rank { get; set; }
    }

    public class CreateProductRequest
    {
        public int? ProductGroupId { get; set; }
        public required string Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public required decimal Price { get; set; }
        public bool? IsTaxInclusivePrice { get; set; }     // default true
        public int? CurrencyId { get; set; }
        public bool? IsPriceChangeAllowed { get; set; }    // default false
        public bool? IsService { get; set; }               // default false
        public bool? IsUsingDefaultQuantity { get; set; }  // default true
        public bool? IsEnabled { get; set; }               // default true
        public string? Description { get; set; }
        public DateTime? DateCreated { get; set; }         // default getdate()
        public DateTime? DateUpdated { get; set; }         // default getdate()
        public decimal? Cost { get; set; }                 // default 0
        public decimal? Markup { get; set; }               // default 0
        public string? ImageBase64 { get; set; }           // optional for query uploads
        public string? Color { get; set; }                 // default Transparent
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }    // default 0
        public int? Rank { get; set; }                     // default 0
    }

    public class UpdateProductRequest
    {
        public int? ProductGroupId { get; set; }
        public required string Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public required decimal Price { get; set; }
        public required bool IsTaxInclusivePrice { get; set; }
        public int? CurrencyId { get; set; }
        public required bool IsPriceChangeAllowed { get; set; }
        public required bool IsService { get; set; }
        public required bool IsUsingDefaultQuantity { get; set; }
        public required bool IsEnabled { get; set; }
        public string? Description { get; set; }
        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }
        public required decimal Cost { get; set; }
        public decimal? Markup { get; set; }
        public string? ImageBase64 { get; set; }
        public required string Color { get; set; }
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }
        public int? Rank { get; set; }
    }
}
