using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperUserDevicePin
    {
        public static UserDevicePinDto MapToUserDevicePinDto(UserDevicePin entity)
        {
            return new UserDevicePinDto
            {
                Id = entity.Id,
                UserId = entity.UserId,
                DeviceId = entity.DeviceId,
                CompanyId = entity.CompanyId,
                HashedPin = entity.HashedPin
            };
        }
    }
}
