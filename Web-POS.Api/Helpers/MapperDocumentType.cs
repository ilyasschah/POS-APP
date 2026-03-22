using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperDocumentType
    {
        public static DocumentTypeDto MapToDocumentTypeDto(DocumentType entity)
        {
            return new DocumentTypeDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Code = entity.Code,
                DocumentCategoryName = entity.DocumentCategory?.Name,
                WarehouseName = entity.Warehouse?.Name
            };
        }
    }
}
