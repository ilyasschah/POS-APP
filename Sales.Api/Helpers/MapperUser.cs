// FILE: Sales.Api.Helpers\MapperUser.cs

using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers;

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
