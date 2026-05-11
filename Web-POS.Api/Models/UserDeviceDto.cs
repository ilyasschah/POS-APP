namespace Api.Models
{
    public class SetDevicePinRequest
    {
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public string Pin { get; set; } = string.Empty;
    }
}
