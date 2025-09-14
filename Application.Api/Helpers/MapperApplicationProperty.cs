using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperApplicationProperty
    {
        public static ApplicationPropertyDto MapToApplicationPropertyDto(ApplicationProperty entity)
        {
            return new ApplicationPropertyDto
            {
                Name = entity.Name,
                Value = entity.Value
            };
        }
    }
}
