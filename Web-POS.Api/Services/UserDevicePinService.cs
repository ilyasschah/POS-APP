using Api.Domain;
using Api.Models;
using Api.Repository;
using System.Security.Cryptography;
using System.Text;

namespace Api.Services;

public class UserDevicePinService
{
    private readonly UserDevicePinRepository _repository;

    public UserDevicePinService(UserDevicePinRepository repository)
    {
        _repository = repository;
    }

    public async Task<string> SetDevicePinAsync(SetDevicePinRequest request , int companyId)
    {
        using var sha256 = SHA256.Create();
        var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(request.Pin));
        var hashedPin = Convert.ToBase64String(hashedBytes);

        var existingPinRecord = await _repository.GetByUserAndDeviceAsync(request.UserId, request.DeviceId, companyId);

        if (existingPinRecord != null)
        {
            existingPinRecord.HashedPin = hashedPin;
            await _repository.UpdateAsync(existingPinRecord);
        }
        else
        {
            var newPinRecord = UserDevicePin.Create(
                request.UserId,
                companyId,
                request.DeviceId,
                hashedPin);

            await _repository.AddAsync(newPinRecord);
        }

        return hashedPin;
    }
    public async Task<bool> RevokeDevicePinAsync(RevokeDeviceRequest request, int companyId, CancellationToken cancellationToken = default)
    {
        var existingPinRecord = await _repository.GetByUserAndDeviceAsync(request.UserId, request.DeviceId, companyId);
        if (existingPinRecord != null)
        {
            existingPinRecord.HashedPin = string.Empty;
            await _repository.UpdateAsync(existingPinRecord);
            return true;
        }
        return false;
    }

}