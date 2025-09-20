using Products.Api.Domain;
using Products.Api.Models;
namespace Products.Api.Helpers
{
    public class MapperDocumentItemExpirationDate
    {
        public static DocumentItemExpirationDateDto MapperToDocumentItemExpirationDate (DocumentItemExpirationDate documentItemExpirationDate)
        {
            return new DocumentItemExpirationDateDto
            {
                DocumentItemId = documentItemExpirationDate.DocumentItemId,
                ExpirationDate = documentItemExpirationDate.ExpirationDate
            };
        }
    }
}
