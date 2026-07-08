using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace Api.Domain
{
    [Table("UserDevicePins")]
    public class UserDevicePin
    {
        [Key]
        public int Id { get; set; }
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public string HashedPin { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; private set; }
        public UserDevicePin() { }

        private UserDevicePin(int userId, int companyId, string deviceId, string hashedPin)
        {
            if (userId <= 0) throw new ArgumentException("Invalid UserId", nameof(userId));
            if (companyId <= 0) throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(deviceId)) throw new ArgumentException("DeviceId cannot be empty", nameof(deviceId));
            if (string.IsNullOrWhiteSpace(hashedPin)) throw new ArgumentException("HashedPin cannot be empty", nameof(hashedPin));
            UserId = userId;
            CompanyId = companyId;
            DeviceId = deviceId;
            HashedPin = hashedPin;
        }
        public static UserDevicePin Create(int userId, int companyId, string deviceId, string hashedPin)
        {
            return new UserDevicePin(userId, companyId, deviceId, hashedPin);
        }
        public void Update(string deviceId, string hashedPin)
        {
            if (string.IsNullOrWhiteSpace(deviceId)) throw new ArgumentException("DeviceId cannot be empty", nameof(deviceId));
            if (string.IsNullOrWhiteSpace(hashedPin)) throw new ArgumentException("HashedPin cannot be empty", nameof(hashedPin));
            DeviceId = deviceId;
            HashedPin = hashedPin;
        }
    }
}