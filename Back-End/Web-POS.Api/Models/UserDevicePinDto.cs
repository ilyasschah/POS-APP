namespace Api.Models;

public class UserDevicePinDto
{
    public int Id { get; set; }
    public string DeviceId { get; set; } = string.Empty;
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