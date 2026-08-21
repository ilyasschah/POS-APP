using Microsoft.AspNetCore.Mvc;
using Api.Domain;
using Api.Models;
using Api.Services;

namespace Api.Controllers;

/// <summary>
/// POS session lifecycle.
///
/// Business failures are thrown as <see cref="InvalidOperationException"/> by
/// the service and mapped to a 400 with the message by the existing middleware,
/// so the client's `_resolveRejection` marks the row `sync_failed` and shows the
/// reason instead of retrying a doomed request forever.
/// </summary>
[Route("api/[controller]")]
[ApiController]
public class PosSessionController(
    PosSessionService sessions,
    ILogger<PosSessionController> logger) : ControllerBase
{
    /// <summary>Open (or re-attach to) a session. Idempotent on LocalId.</summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionDto>> Open(
        [FromBody] OpenPosSessionRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");

        var session = await sessions.OpenAsync(
            companyId, request.UserId, request.DeviceUid, request.DeviceName,
            request.OpeningCash, request.LocalId, request.OpenedAt, ct);

        return Ok(Map(session));
    }

    /// <summary>OPENING_CONTROL → OPENED with the counted opening float.</summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionDto>> ConfirmOpening(
        [FromBody] ConfirmOpeningRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var session = await sessions.ConfirmOpeningAsync(
            companyId, request.SessionId, request.CountedOpeningCash, ct);
        return Ok(Map(session));
    }

    /// <summary>
    /// The session this register is currently running, if any. Drives the
    /// "Open Register" vs "Continue Selling" choice on the client.
    /// </summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<PosSessionDto?>> Current(
        [FromQuery] int companyId,
        [FromQuery] string deviceUid,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        if (string.IsNullOrWhiteSpace(deviceUid)) return BadRequest("deviceUid is required.");

        var session = await sessions.GetLiveForDeviceAsync(companyId, deviceUid, ct);
        return Ok(session is null ? null : Map(session));
    }

    /// <summary>Closing figures — expected cash and the per-method rows.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<PosSessionSummaryDto>> Summary(
        [FromQuery] int companyId,
        [FromQuery] int sessionId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await sessions.BuildSummaryAsync(companyId, sessionId, ct));
    }

    /// <summary>
    /// Reasons the SERVER can see not to close. The client adds what only it
    /// knows — parked orders and its own unsynced queue.
    /// </summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<string>>> CloseBlockers(
        [FromQuery] int companyId,
        [FromQuery] int sessionId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await sessions.GetCloseBlockersAsync(companyId, sessionId, ct));
    }

    /// <summary>OPENED → CLOSING_CONTROL. Selling stops immediately.</summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionSummaryDto>> EnterClosingControl(
        [FromQuery] int companyId,
        [FromQuery] int sessionId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await sessions.EnterClosingControlAsync(companyId, sessionId, ct));
    }

    /// <summary>CLOSING_CONTROL → CLOSED with the counted drawer.</summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionDto>> Close(
        [FromBody] ClosePosSessionRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");

        var session = await sessions.CloseAsync(
            companyId, request.SessionId, request.UserId, request.CountedCash,
            request.Counts, request.ClosingNote, request.ManagerAuthorised, ct);

        return Ok(Map(session));
    }

    /// <summary>
    /// Admin-only close for an unreachable register.
    ///
    /// ⚠️ Authorisation is checked by the CALLER's access level, which the client
    /// gates on (`accessLevel == 0`). A server-side policy attribute belongs
    /// here too — tracked with the rest of the `/api/Master/*` lockdown
    /// (backlog item 12) rather than invented ad hoc for this one endpoint.
    /// </summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionDto>> ForceClose(
        [FromBody] ForceClosePosSessionRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");

        logger.LogWarning(
            "Force-close requested for session {Session} by user {User}.",
            request.SessionId, request.UserId);

        var session = await sessions.ForceCloseAsync(
            companyId, request.SessionId, request.UserId, request.Reason, ct);
        return Ok(Map(session));
    }

    /// <summary>
    /// Offline push: reconcile a device's session state. **Idempotent** — the
    /// same payload may be sent any number of times and only the first has an
    /// effect. This is what protects against a lost response being retried.
    /// </summary>
    [HttpPost("[action]")]
    public async Task<ActionResult<PosSessionDto>> Sync(
        [FromBody] SyncPosSessionRequest request,
        [FromQuery] int companyId,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var session = await sessions.SyncFromDeviceAsync(companyId, request, ct);
        return Ok(Map(session));
    }

    /// <summary>Session history, newest first, optionally for one register.</summary>
    [HttpGet("[action]")]
    public async Task<ActionResult<List<PosSessionDto>>> History(
        [FromQuery] int companyId,
        [FromQuery] int? posDeviceId,
        [FromQuery] int take = 50,
        CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var list = await sessions.GetHistoryAsync(companyId, posDeviceId, take, ct);
        return Ok(list.Select(Map).ToList());
    }

    private static PosSessionDto Map(Shift s) => new()
    {
        Id = s.Id,
        LocalId = s.LocalId,
        CompanyId = s.CompanyId,
        PosDeviceId = s.PosDeviceId,
        PosDeviceName = s.PosDevice?.Name,
        OpenedByUserId = s.UserId,
        OpenedAt = s.OpenedAt,
        ClosedByUserId = s.ClosedByUserId,
        ClosedAt = s.ClosedAt,
        OpeningCash = s.StartingCash,
        ExpectedCash = s.ExpectedCash,
        ActualEndingCash = s.ActualEndingCash,
        CashDifference = s.CashDifference,
        ClosingNote = s.ClosingNote,
        Status = s.Status,
        StatusName = PosSessionStatus.Name(s.Status),
        ForceClosed = s.ForceClosed,
        ForceClosedByUserId = s.ForceClosedByUserId,
        ForceCloseReason = s.ForceCloseReason,
        HasLateArrivals = s.HasLateArrivals,
        LastModified = s.LastModified,
    };
}
