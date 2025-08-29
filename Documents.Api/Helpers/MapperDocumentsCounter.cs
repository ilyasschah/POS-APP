using Documents.Api.Domain;
using Documents.Api.Models;

namespace Documents.Api.Helpers
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