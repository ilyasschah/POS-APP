using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocumentsCounter
    {
        public static DocumentsCounterDto MapToDocumentsCounterDto(DocumentsCounter entity)
        {
            return new DocumentsCounterDto
            {
                Name = entity.Name,
                Value = entity.Value,
                CompanyId = entity.CompanyId
            };
        }
    }
}