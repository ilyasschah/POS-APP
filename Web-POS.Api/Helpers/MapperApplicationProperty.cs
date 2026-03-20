using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperApplicationProperty
    {
        public static ApplicationPropertyDto MapToApplicationPropertyDto(ApplicationProperty entity)
        {
            if (entity == null) return null;

            return new ApplicationPropertyDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Value = entity.Value,
                CompanyName = entity.Company?.Name
            };
        }
    }
}