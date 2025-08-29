using Documents.Api.Domain;
using Documents.Api.Models.DocumentTypes;

namespace Documents.Api.Helpers
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
