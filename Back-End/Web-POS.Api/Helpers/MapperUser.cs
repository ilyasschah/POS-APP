using Api.Domain;
using Api.Models;

namespace Api.Helpers
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
                Email = entity.Email,
                CompanyId = entity.CompanyId,
            };
        }
    }
}