using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Api.Services;

public class TokenService
{
    private readonly IConfiguration _config;

    public TokenService(IConfiguration config)
    {
        _config = config;
    }

    public (string token, int expiresIn) CreateJwt(string username)
    {
        var issuer = _config["Jwt:Issuer"] ?? "Products.Api";
        var audience = _config["Jwt:Audience"] ?? "Products.Clients";
        var minutes = int.TryParse(_config["Jwt:ExpireMinutes"], out var m) ? m : 60;
        var secret = _config["Jwt:Secret"] ?? "dev-only-very-long-secret-change-me-please";

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