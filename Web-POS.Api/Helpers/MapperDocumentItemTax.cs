using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperDocumentItemTax
    {
        public static DocumentItemTaxDto MapperToDocumenItemTax (DocumentItemTax documentItemTax)
        {
            return new DocumentItemTaxDto
            {
                DocumentItemId = documentItemTax.DocumentItemId,
                TaxID = documentItemTax.TaxID,
                TaxName = documentItemTax.Tax?.Name,
                Amount = documentItemTax.Amount
            };
        }
    }
}
