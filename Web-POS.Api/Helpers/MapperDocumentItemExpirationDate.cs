using Api.Domain;
using Api.Models;
namespace Api.Helpers
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
