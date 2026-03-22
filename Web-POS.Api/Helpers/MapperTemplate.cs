using Api.Domain;
using Api.Models;

namespace Api.Helpers
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
