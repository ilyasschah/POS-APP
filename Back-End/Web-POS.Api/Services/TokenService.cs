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

    /// <param name="accessLevel">0 = Admin (manager), 1 = Cashier. Mapped to the
    /// <c>role</c> claim so server-side <c>[Authorize(Policy = "ManagerOnly")]</c>
    /// reflects the real account level instead of a hardcoded "Admin".</param>
    /// <param name="userId">The POS user this token acts as. Carried as the
    /// <c>userId</c> claim for per-user authorization + audit — set to the current
    /// cashier when a per-user token is minted via /Auth/UserToken.</param>
    public (string token, int expiresIn) CreateJwt(string username, int userId, int accessLevel, int companyId)
    {
        var issuer = _config["Jwt:Issuer"] ?? "Products.Api";
        var audience = _config["Jwt:Audience"] ?? "Products.Clients";
        // Default 7 days. The token only gates online admin-write endpoints, so a
        // wide window is safe; a refresh-on-sync slides it forward for live devices.
        var minutes = int.TryParse(_config["Jwt:ExpireMinutes"], out var m) ? m : 10080;
        var secret = _config["Jwt:Secret"] ?? "dev-only-very-long-secret-change-me-please";

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        // accessLevel 0 = Admin/manager, anything else = Cashier.
        var role = accessLevel == 0 ? "Admin" : "Cashier";

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, username),
            new Claim(ClaimTypes.Name, username),
            new Claim(ClaimTypes.Role, role),
            new Claim("userId", userId.ToString()),
            new Claim("accessLevel", accessLevel.ToString()),
            new Claim("companyId", companyId.ToString()),
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