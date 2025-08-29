using Documents.Api.Domain;
using Documents.Api.Models;

namespace Documents.Api.Helpers
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
