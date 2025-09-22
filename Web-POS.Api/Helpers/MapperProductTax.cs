using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperProductTax
    {
        public static ProductTaxDto MapToProductTaxDto(ProductTax entity)
        {
            return new ProductTaxDto
            {
                ProductId = entity.ProductId,
                ProductName = entity.Product?.Name ?? "N/A",
                TaxId = entity.TaxId,
                TaxName = entity.Tax?.Name ?? "N/A",
                TaxRate = entity.Tax?.Rate ?? 0
            };
        }
    }
}