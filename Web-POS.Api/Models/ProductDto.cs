using System;

namespace Api.Models
{
    public class TaxExportDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public decimal Rate { get; set; }
        public string? Code { get; set; }
        public bool IsFixed { get; set; }
        public bool IsTaxOnTotal { get; set; }
        public bool IsEnabled { get; set; }
    }

    public class ProductExportDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public string? ProductGroupName { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public decimal Cost { get; set; }
        public decimal? Markup { get; set; }
        public decimal Price { get; set; }
        public bool IsTaxInclusivePrice { get; set; }
        public bool IsPriceChangeAllowed { get; set; }
        public bool IsUsingDefaultQuantity { get; set; }
        public bool IsService { get; set; }
        public bool IsEnabled { get; set; }
        public string? Description { get; set; }
        public decimal TotalStock { get; set; }
        public string? SupplierName { get; set; }
        public decimal ReorderPoint { get; set; }
        public decimal PreferredQuantity { get; set; }
        public bool IsLowStockWarningEnabled { get; set; }
        public decimal LowStockWarningQuantity { get; set; }
        public string Color { get; set; } = "Transparent";
        public int? Rank { get; set; }
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }
        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }
        public List<string> Barcodes { get; set; } = [];
        public List<TaxExportDto> Taxes { get; set; } = [];
        public List<string> Comments { get; set; } = [];
    }


    public class ProductDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public int? ProductGroupId { get; set; }
        public string? ProductGroupName { get; set; }
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
        public List<string> Barcodes { get; set; } = new();
        public DateTime LastModified { get; set; }
    }

    public class ImportProductRow
    {
        public string Name { get; set; } = default!;
        public string? ProductGroupName { get; set; }
        public string? Code { get; set; }
        public string? Barcode { get; set; }
        public string? MeasurementUnit { get; set; }
        public decimal? Cost { get; set; }
        public decimal? Markup { get; set; }
        public decimal? Price { get; set; }
        public decimal? TaxRate { get; set; }
        public bool? IsTaxInclusivePrice { get; set; }
        public bool? IsPriceChangeAllowed { get; set; }
        public bool? IsUsingDefaultQuantity { get; set; }
        public bool? IsService { get; set; }
        public bool? IsEnabled { get; set; }
        public string? Description { get; set; }
        public decimal? Quantity { get; set; }
        public string? SupplierName { get; set; }
        public decimal? ReorderPoint { get; set; }
        public decimal? PreferredQuantity { get; set; }
        public bool? IsLowStockWarningEnabled { get; set; }
        public decimal? LowStockWarningQuantity { get; set; }
    }

    public class ImportProductsRequest
    {
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public bool SkipDuplicates { get; set; }
        public bool MergeDuplicates { get; set; }
        public string DocumentType { get; set; } = "inventoryCount";
        public List<ImportProductRow> Rows { get; set; } = [];
    }

    public class ImportProductsResult
    {
        public int Created { get; set; }
        public int Updated { get; set; }
        public int Skipped { get; set; }
        public string? DocumentNumber { get; set; }
        public List<string> Errors { get; set; } = [];
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
        public int Id { get; set; }
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
