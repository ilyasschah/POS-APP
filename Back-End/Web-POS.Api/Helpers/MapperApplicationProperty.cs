using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperApplicationProperty
    {
        public static ApplicationPropertyDto MapToApplicationPropertyDto(ApplicationProperty entity)
        {
            if (entity == null) return null;

            return new ApplicationPropertyDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                Name = entity.Name,
                Value = entity.Value,
                CompanyName = entity.Company?.Name,
                LastModified = entity.LastModified
            };
        }
    }
}