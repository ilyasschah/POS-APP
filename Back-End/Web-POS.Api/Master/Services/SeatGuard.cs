using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Api.Master.Services
{
    /// <summary>
    /// Pillar 4 seat-cap gate shared by every BatchSync ingress endpoint. Reads
    /// the <c>X-Device-Id</c> header, registers the device (up to the tenant's
    /// paid allowance) or returns a 403 for an over-cap / blocked device. Returns
    /// <c>null</c> when the request may proceed.
    ///
    /// Fail-OPEN on any other outcome (no header, unprovisioned tenant, control
    /// plane unavailable) so a Master-DB hiccup or a not-yet-updated client never
    /// blocks a paying customer — seat abuse is still caught by the Pillar-5 audit.
    /// </summary>
    public static class SeatGuard
    {
        public static async Task<ActionResult?> CheckAsync(
            HttpRequest request, ITenantProvisioningService provisioning, int companyId)
        {
            var deviceId = request.Headers["X-Device-Id"].ToString();
            if (string.IsNullOrWhiteSpace(deviceId)) return null;

            try
            {
                var seat = await provisioning.RegisterOrValidateDeviceAsync(
                    companyId, deviceId, request.Headers["X-Device-Name"].ToString());

                if (!seat.Allowed &&
                    (seat.Reason == "seat_limit_exceeded" ||
                     seat.Reason == "device_blocked" ||
                     seat.Reason == "device_revoked"))
                {
                    return new ObjectResult(new
                    {
                        success = false,
                        error = seat.Reason,
                        message = seat.Reason switch
                        {
                            "seat_limit_exceeded" =>
                                $"This account is licensed for {seat.SeatAllowance} terminal(s) and that limit is reached — this device is not authorized to sync.",
                            "device_revoked" =>
                                "This terminal was removed from the account. Sign in again to reconnect it.",
                            _ => "This device has been blocked by the account administrator.",
                        },
                        activeSeats = seat.ActiveSeats,
                        seatAllowance = seat.SeatAllowance,
                    })
                    { StatusCode = StatusCodes.Status403Forbidden };
                }
            }
            catch
            {
                // Control plane unavailable — fail open (see summary above).
            }
            return null;
        }
    }
}
