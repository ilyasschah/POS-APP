namespace Api.Models;

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class LoginResponse
{
    public bool Success { get; set; }
    public string Token { get; set; } = string.Empty;
    public string TokenType { get; set; } = "Bearer";
    public int ExpiresIn { get; set; } = 3600;
    public object? User { get; set; }
    public string? Message { get; set; }
}