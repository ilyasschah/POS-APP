using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperDocumentsCounter
    {
        public static DocumentsCounterDto MapToDocumentsCounterDto(DocumentsCounter entity)
        {
            return new DocumentsCounterDto
            {
                Name = entity.Name,
                Value = entity.Value
            };
        }
    }
}