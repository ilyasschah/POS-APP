using Api.Attributes;
using Api.Commands.UserCommands.Delete;
using Api.Domain;
using Api.Models;
using Api.Queries.UserQuery;
using Api.Repository;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace Api.Controllers;

[SwaggerVisible]
[ApiController]
[Route("api/[controller]")]
public class AuthController(IConfiguration config , IMediator mediator) : ControllerBase
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
        if (!string.Equals(body.Username, DemoUsername, StringComparison.OrdinalIgnoreCase) ||
            body.Password != DemoPassword)
        {
            return Unauthorized(new { message = "Invalid credentials." });
        }

        var (token, expiresIn) = CreateJwt(body.Username);
        return Ok(new LoginResponse { Success = true, Token = token, ExpiresIn = expiresIn });
    }
    [HttpPost("SetDevicePin")]
    public async Task<IActionResult> SetDevicePin([FromBody] SetDevicePinRequest body,[FromServices] UserDevicePinRepository pinRepo)
    {
        if (string.IsNullOrWhiteSpace(body.Pin) || body.Pin.Length < 4)
            return BadRequest(new { message = "PIN must be at least 4 digits." });

        if (string.IsNullOrWhiteSpace(body.DeviceId))
            return BadRequest(new { message = "Device ID is required." });
        using var sha256 = SHA256.Create();
        var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(body.Pin));
        var hashedPin = Convert.ToBase64String(hashedBytes);
        var existingPinRecord = await pinRepo.GetByUserAndDeviceAsync(body.UserId, body.DeviceId);

        if (existingPinRecord != null)
        {
            existingPinRecord.HashedPin = hashedPin;
            await pinRepo.UpdateAsync(existingPinRecord);
        }
        else
        {
            var newPinRecord = new UserDevicePin
            {
                UserId = body.UserId,
                CompanyId = body.CompanyId,
                DeviceId = body.DeviceId,
                HashedPin = hashedPin,
                CreatedAt = DateTime.UtcNow
            };
            await pinRepo.AddAsync(newPinRecord);
        }

        return Ok(new
        {
            Success = true,
            Message = "Device PIN set successfully.",
            HashedPin = hashedPin
        });
    }
    [HttpGet("GetActiveDevices")]
    public async Task<ActionResult<List<UserDeviceDto>>> GetActiveDevices([FromQuery] int userId, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetActiveDevicesQuery { UserId = userId, CompanyId = companyId });
        return Ok(result);
    }

    [HttpDelete("RevokeDevice")]
    public async Task<ActionResult> RevokeDevice([FromQuery] int userId, [FromQuery] string deviceId, [FromQuery] int companyId)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new RevokeDeviceCommand { UserId = userId, DeviceId = deviceId, CompanyId = companyId });
        if (!result) return NotFound("Device or PIN not found.");
        return Ok(new { Success = true, Message = "Device revoked successfully" });
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
