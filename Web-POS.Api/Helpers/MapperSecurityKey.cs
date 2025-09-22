using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperSecurityKey
    {
        public static SecurityKeyDto MapToSecurityKey(SecurityKey securityKey)
        {
            return new SecurityKeyDto
            {
                Name = securityKey.Name,
                Level = securityKey.Level,
            };
        }
    }
}
