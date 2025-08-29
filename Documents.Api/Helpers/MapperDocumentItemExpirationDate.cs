using Documents.Api.Domain;
using Documents.Api.Models;
namespace Documents.Api.Helpers
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
