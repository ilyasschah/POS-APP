using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperApplicationProperty
    {
        public static ApplicationPropertyDto MapToApplicationPropertyDto(ApplicationProperty entity)
        {
            return new ApplicationPropertyDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                Name = entity.Name ?? string.Empty,
                Value = entity.Value ?? string.Empty,
                CompanyName = entity.Company?.Name,
                LastModified = entity.LastModified
            };
        }
    }
}