using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperTemplate
    {
        public static TemplateDto MapToTemplateDto(Template entity)
        {
            return new TemplateDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Value = entity.Value
            };
        }
    }
}
