using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperDocumentCategory
    {
        public static DocumentCategoryDto MapDocumentCategory(DocumentCategory documentCategory)
        {
            return new DocumentCategoryDto
            {
                Id = documentCategory.Id,
                Name = documentCategory.Name,
                LanguageKey = documentCategory.LanguageKey
            };
        }
    }
}
