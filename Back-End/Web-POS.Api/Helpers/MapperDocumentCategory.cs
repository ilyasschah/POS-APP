using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperDocumentCategory
    {
        public static DocumentCategoryDto MapDocumentCategory(DocumentCategory documentCategory)
        {
            return new DocumentCategoryDto
            {
                Id = documentCategory.Id,
                Name = documentCategory.Name ?? string.Empty,
                LanguageKey = documentCategory.LanguageKey
            };
        }
    }
}
