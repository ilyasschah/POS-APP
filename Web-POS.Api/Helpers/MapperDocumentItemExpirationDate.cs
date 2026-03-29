using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocumentItemExpirationDate
    {
        public static DocumentItemExpirationDateDto MapToDocumentItemExpirationDateDto(DocumentItemExpirationDate entity)
        {
            return new DocumentItemExpirationDateDto
            {
                DocumentItemId = entity.DocumentItemId,
                ExpirationDate = entity.ExpirationDate
            };
        }
    }
}