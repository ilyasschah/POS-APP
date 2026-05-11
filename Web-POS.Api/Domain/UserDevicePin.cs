namespace Api.Domain
{
    public class UserDevicePin
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public string HashedPin { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}