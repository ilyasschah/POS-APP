namespace Api.Models;

public class UserDto
{
    public int Id { get; set; }
    public int CompanyId { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Username { get; set; }
    public int AccessLevel { get; set; }
    public bool IsEnabled { get; set; }
    public string? Email { get; set; }
    public bool HasPinForThisDevice { get; set; }
    public string? HashedPin { get; set; }
    public DateTime LastModified { get; set; }
}

public class CreateUserRequest
{
    public required string Username { get; set; }
    public required string Password { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public int AccessLevel { get; set; }
    public bool IsEnabled { get; set; }
    public string? Email { get; set; }
}

public class UpdateUserRequest
{
        public required int Id { get; set; }
        public string? Username { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public int? AccessLevel { get; set; }
        public bool? IsEnabled { get; set; }
        public string? Email { get; set; }
    
}
public class ChangePasswordRequest
{
    public int UserId { get; set; }
    public string OldPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
public class AdminResetPasswordRequest
{
    public int UserId { get; set; }
    public required string NewPassword { get; set; }
}

