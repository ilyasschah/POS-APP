namespace Api.Models
{
    public class UserDeviceDto
    {
        public string DeviceId { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
    public class SetDevicePinRequest
    {
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public string Pin { get; set; } = string.Empty;
    }
    public class ChangePasswordRequest
    {
        public int UserId { get; set; }
        public string OldPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
