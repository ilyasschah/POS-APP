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
                DocumentCategoryId = entity.DocumentCategoryId,
                DocumentCategoryName = entity.DocumentCategory.Name,
                StockDirection = entity.StockDirection,
                EditorType = entity.EditorType,
                PrintTemplate = entity.PrintTemplate,
                PriceType = entity.PriceType,
                LanguageKey = entity.LanguageKey
            };
        }
    }
}
