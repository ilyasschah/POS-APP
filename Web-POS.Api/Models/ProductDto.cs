using System;

namespace Api.Models
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
        public int CompanyId { get; set; }
        public required string Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public required decimal Price { get; set; }
        public bool? IsTaxInclusivePrice { get; set; }    
        public int? CurrencyId { get; set; }
        public bool? IsPriceChangeAllowed { get; set; }   
        public bool? IsService { get; set; }              
        public bool? IsUsingDefaultQuantity { get; set; } 
        public bool? IsEnabled { get; set; }              
        public string? Description { get; set; }
        public DateTime? DateCreated { get; set; }        
        public DateTime? DateUpdated { get; set; }        
        public decimal? Cost { get; set; }                
        public decimal? Markup { get; set; }              
        public string? ImageBase64 { get; set; }          
        public string? Color { get; set; }                
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }   
        public int? Rank { get; set; }                    
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
