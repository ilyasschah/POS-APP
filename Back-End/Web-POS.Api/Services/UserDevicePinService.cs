using Api.Domain;
using Api.Models;
using Api.Repository;
using System.Security.Cryptography;
using System.Text;

namespace Api.Services;

public class UserDevicePinService
{
    private readonly UserDevicePinRepository _repository;
    private readonly Api.Master.Services.ITenantProvisioningService _provisioning;

    public UserDevicePinService(
        UserDevicePinRepository repository,
        Api.Master.Services.ITenantProvisioningService provisioning)
    {
        _repository = repository;
        _provisioning = provisioning;
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
        // 🚨 Blanking the PIN alone was never a revoke. It stopped THIS user
        // PIN-ing in on that terminal, and nothing else: the device kept its
        // master session, kept syncing, and kept occupying a paid seat — it did
        // not appear removed anywhere the admin could see, and it never signed
        // out. Removing a terminal has to reach the DeviceRegistry too.
        //
        // Every user's PIN on the terminal is cleared, not just the caller's: the
        // registry row is deleted for the whole account, so leaving another
        // cashier's PIN behind would keep the device listed on their screen —
        // pointing at a device that is no longer enrolled at all.
        var pinRecords = await _repository.GetByDeviceAsync(request.DeviceId, companyId, cancellationToken);
        foreach (var pin in pinRecords) pin.HashedPin = string.Empty;
        if (pinRecords.Count > 0) await _repository.SaveChangesAsync(cancellationToken);

        // Control plane lives in a SEPARATE database, so this cannot join the
        // transaction above. Non-fatal: a Master-DB hiccup must not fail the PIN
        // revoke, and the next revoke is idempotent.
        var deviceRevoked = false;
        try
        {
            deviceRevoked = await _provisioning.RevokeDeviceAsync(
                companyId, request.DeviceId, cancellationToken);
        }
        catch
        {
            // The registry row survives until this is retried; the PINs are gone.
        }

        return pinRecords.Count > 0 || deviceRevoked;
    }

}