using Api.Domain;
using Api.Models;

namespace Api.Helpers
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
