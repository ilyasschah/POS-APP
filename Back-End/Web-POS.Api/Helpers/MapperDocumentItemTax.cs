using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocumentItemTax
    {
        public static DocumentItemTaxDto MapToDocumentItemTaxDto(DocumentItemTax entity)
        {
            return new DocumentItemTaxDto
            {
                DocumentItemId = entity.DocumentItemId,
                TaxId = entity.TaxId,
                TaxName = entity.Tax?.Name ?? "N/A",
                Amount = entity.Amount
            };
        }
    }
}