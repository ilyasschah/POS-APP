using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperUser
    {
        public static UserDto MapToUserDto(User entity)
        {
            return new UserDto
            {
                Id = entity.Id,
                FirstName = entity.FirstName,
                LastName = entity.LastName,
                Username = entity.Username,
                AccessLevel = entity.AccessLevel,
                IsEnabled = entity.IsEnabled,
                Email = entity.Email 
            };
        }
    }
}