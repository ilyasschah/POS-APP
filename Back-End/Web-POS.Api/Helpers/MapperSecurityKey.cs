using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperSecurityKey
    {
        public static SecurityKeyDto MapToDto(SecurityKey entity)
        {
            return new SecurityKeyDto
            {
                Name = entity.Name,
                Level = entity.Level
            };
        }
    }
}