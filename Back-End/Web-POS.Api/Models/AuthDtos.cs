namespace Api.Models;

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    /// <summary>Device signature (Pillar 4) — registered against the seat cap at login.</summary>
    public string? DeviceId { get; set; }
}

public class LoginResponse
{
    public bool Success { get; set; }
    public string Token { get; set; } = string.Empty;
    public string TokenType { get; set; } = "Bearer";
    public int ExpiresIn { get; set; } = 3600;
    public object? User { get; set; }
    public string? Message { get; set; }

    /// <summary>
    /// Pillar 2: signed offline subscription lease for the user's company. The
    /// app stores it on the device and reads its <c>validUntil</c> claim on boot
    /// to enforce the subscription offline.
    /// </summary>
    public string? Lease { get; set; }
}