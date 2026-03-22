using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(IConfiguration config) : ControllerBase
{
    // ---- TEMP credentials so you can test immediately
    // username: admin   password: Admin@123
    private const string DemoUsername = "admin";
    private const string DemoPassword = "Admin@123";

    public sealed class LoginRequest
    {
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
    }

    public sealed class LoginResponse
    {
        public bool Success { get; set; }
        public string Token { get; set; } = "";
        public string TokenType { get; set; } = "Bearer";
        public int ExpiresIn { get; set; } = 3600;
        public object User { get; set; } = new { Id = 1, Username = DemoUsername, Roles = new[] { "Admin" } };
        public string? Message { get; set; }
    }

    [HttpPost("[action]")]
    public ActionResult<LoginResponse> Login([FromBody] LoginRequest body)
    {
        if (string.IsNullOrWhiteSpace(body.Username) || string.IsNullOrWhiteSpace(body.Password))
            return BadRequest(new { message = "Username and password are required." });

        // Step-1: in-memory check. (Next step we’ll switch to DB + hash.)
        if (!string.Equals(body.Username, DemoUsername, StringComparison.OrdinalIgnoreCase) ||
            body.Password != DemoPassword)
        {
            return Unauthorized(new { message = "Invalid credentials." });
        }

        var (token, expiresIn) = CreateJwt(body.Username);
        return Ok(new LoginResponse { Success = true, Token = token, ExpiresIn = expiresIn });
    }

    private (string token, int expiresIn) CreateJwt(string username)
    {
        var issuer = config["Jwt:Issuer"] ?? "Products.Api";
        var audience = config["Jwt:Audience"] ?? "Products.Clients";
        var minutes = int.TryParse(config["Jwt:ExpireMinutes"], out var m) ? m : 60;
        var secret = config["Jwt:Secret"] ?? "dev-only-very-long-secret-change-me-please";

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, username),
            new Claim(ClaimTypes.Name, username),
            new Claim(ClaimTypes.Role, "Admin"),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: DateTime.UtcNow.AddMinutes(minutes),
            signingCredentials: creds
        );

        return (new JwtSecurityTokenHandler().WriteToken(token), minutes * 60);
    }
}
