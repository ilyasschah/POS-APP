namespace Api.Models;

public class UserDevicePinDto
{
    public int Id { get; set; }
    public string DeviceId { get; set; } = string.Empty;

    /// <summary>
    /// Operator-facing terminal name ("POS1"), read from the Master DB's
    /// DeviceRegistry — a SEPARATE database, so it is merged in the query handler
    /// rather than joined. Null for a device that has never reported one; the UI
    /// falls back to the id.
    /// </summary>
    public string? DeviceName { get; set; }

    public DateTime CreatedAt { get; set; }
    public int UserId { get; set; }
    public string? Username { get; set; }
    public string? UserDisplayName { get; set; }    
    public int CompanyId { get; set; }
    public string HashedPin { get; set; } = string.Empty;
}

public class SetDevicePinRequest
{
    public int UserId { get; set; }
    public string DeviceId { get; set; } = string.Empty;
    public string Pin { get; set; } = string.Empty;
}
public class RevokeDeviceRequest
{
    public int UserId { get; set; }
    public string DeviceId { get; set; } = string.Empty;
}