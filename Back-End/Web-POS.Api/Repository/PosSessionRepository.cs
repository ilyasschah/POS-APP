using Microsoft.EntityFrameworkCore;
using Api.Domain;
using Api.DataBase;

namespace Api.Repository;

/// <summary>
/// Data access for POS sessions and their registers.
///
/// A "session" is a <see cref="Shift"/> row with a non-null
/// <see cref="Shift.PosDeviceId"/>. Every query here filters on that, so
/// attendance shifts — which live in the same table and are read through
/// <see cref="ShiftRepository"/> — can never be returned by accident.
/// </summary>
public class PosSessionRepository(AppDbContext db)
{
    // ── Devices ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Finds or creates the register row for a device GUID, and refreshes its
    /// name/last-seen.
    ///
    /// Upsert rather than "create if the client says it is new": the client
    /// cannot know whether the server has seen this terminal before (it may
    /// have been offline since before it was first registered), so the only
    /// safe contract is "here is my id, give me my row". The unique index on
    /// (CompanyId, DeviceUid) is what makes a concurrent double-open collapse
    /// into one row instead of two registers.
    /// </summary>
    public async Task<PosDevice> GetOrCreateDeviceAsync(
        int companyId, string deviceUid, string? deviceName, CancellationToken ct = default)
    {
        var uid = deviceUid.Trim();
        var device = await db.PosDevices
            .FirstOrDefaultAsync(d => d.CompanyId == companyId && d.DeviceUid == uid, ct);

        if (device is null)
        {
            device = PosDevice.Create(companyId, uid, deviceName);
            db.PosDevices.Add(device);
        }
        else
        {
            device.Touch(deviceName);
        }
        return device;
    }

    // ── Sessions ──────────────────────────────────────────────────────────────

    /// <summary>The session a register is currently running, if any.</summary>
    public Task<Shift?> GetLiveForDeviceAsync(int posDeviceId, CancellationToken ct = default) =>
        db.Shifts.FirstOrDefaultAsync(
            s => s.PosDeviceId == posDeviceId && PosSessionStatus.Live.Contains(s.Status), ct);

    /// <summary>
    /// Looks a session up by the client's UUID. This is the idempotency key for
    /// offline opens — a device that never got its response re-pushes the same
    /// localId, and finding the row here is what turns a retry into a no-op
    /// instead of a second session.
    /// </summary>
    public Task<Shift?> GetByLocalIdAsync(int companyId, string localId, CancellationToken ct = default) =>
        db.Shifts.FirstOrDefaultAsync(
            s => s.CompanyId == companyId && s.LocalId == localId, ct);

    /// <summary>
    /// Resolves a client localId to a session whatever its state.
    ///
    /// Deliberately not "must be OPENED": a cash movement or a late sale can
    /// legitimately belong to a session that has since closed, and the link is
    /// what makes it reconcilable. State rules belong to the caller.
    /// </summary>
    public Task<Shift?> ResolveSessionAsync(
        int companyId, string localId, CancellationToken ct = default) =>
        GetByLocalIdAsync(companyId, localId.Trim(), ct);

    public Task<Shift?> GetSessionAsync(int companyId, int sessionId, CancellationToken ct = default) =>
        db.Shifts.FirstOrDefaultAsync(
            s => s.Id == sessionId && s.CompanyId == companyId && s.PosDeviceId != null, ct);

    public Task<List<Shift>> GetHistoryAsync(
        int companyId, int? posDeviceId, int take, CancellationToken ct = default) =>
        db.Shifts.AsNoTracking()
            // The list shows every register's sessions, so the device row has to
            // come with them — otherwise each row needs its own lookup.
            .Include(s => s.PosDevice)
            .Where(s => s.CompanyId == companyId && s.PosDeviceId != null)
            .Where(s => posDeviceId == null || s.PosDeviceId == posDeviceId)
            .OrderByDescending(s => s.OpenedAt)
            .Take(take)
            .ToListAsync(ct);

    // ── Money in a session ────────────────────────────────────────────────────

    /// <summary>
    /// Payments taken during a session, grouped by method. Drives both the
    /// expected-cash figure and the per-method rows of the closing dialog.
    /// </summary>
    public async Task<List<(int PaymentTypeId, decimal Total)>> GetPaymentTotalsAsync(
        int sessionId, CancellationToken ct = default)
    {
        var rows = await db.Payments.AsNoTracking()
            .Where(p => p.SessionId == sessionId)
            .GroupBy(p => p.PaymentTypeId)
            .Select(g => new { PaymentTypeId = g.Key, Total = g.Sum(x => x.Amount) })
            .ToListAsync(ct);
        return rows.Select(r => (r.PaymentTypeId, r.Total)).ToList();
    }

    /// <summary>Cash in (type 0) and cash out (type 1) for a session.</summary>
    public async Task<(decimal In, decimal Out)> GetCashMovementTotalsAsync(
        int sessionId, CancellationToken ct = default)
    {
        var rows = await db.StartingCashes.AsNoTracking()
            .Where(sc => sc.SessionId == sessionId)
            .Select(sc => new { sc.StartingCashType, sc.Amount })
            .ToListAsync(ct);

        return (
            rows.Where(r => r.StartingCashType == 0).Sum(r => r.Amount),
            rows.Where(r => r.StartingCashType == 1).Sum(r => r.Amount));
    }

    /// <summary>
    /// How many DOCUMENTS the session banked.
    ///
    /// 🚨 Documents, not PosOrders. Checkout CONSUMES the PosOrder row — it
    /// creates the document and deletes the order — so counting orders counts
    /// only what is still unpaid, which on a healthy session is zero. That is
    /// exactly the "0 orders" a till that sold all day was reporting.
    /// </summary>
    public Task<int> GetOrderCountAsync(int sessionId, CancellationToken ct = default) =>
        db.Documents.AsNoTracking().CountAsync(d => d.SessionId == sessionId, ct);

    public Task<List<PaymentType>> GetPaymentTypesAsync(int companyId, CancellationToken ct = default) =>
        db.PaymentTypes.AsNoTracking().Where(p => p.CompanyId == companyId).ToListAsync(ct);

    public Task<List<PosSessionPaymentCount>> GetCountsAsync(int sessionId, CancellationToken ct = default) =>
        db.PosSessionPaymentCounts.AsNoTracking()
            .Where(c => c.SessionId == sessionId).ToListAsync(ct);

    public void AddCount(PosSessionPaymentCount count) => db.PosSessionPaymentCounts.Add(count);

    public void AddSession(Shift session) => db.Shifts.Add(session);

    public async Task ClearCountsAsync(int sessionId, CancellationToken ct = default)
    {
        var existing = await db.PosSessionPaymentCounts
            .Where(c => c.SessionId == sessionId).ToListAsync(ct);
        db.PosSessionPaymentCounts.RemoveRange(existing);
    }

    /// <summary>Company setting lookup — the cash tolerance and cash-method override.</summary>
    public async Task<string?> GetSettingAsync(int companyId, string name, CancellationToken ct = default)
    {
        var row = await db.ApplicationProperties.AsNoTracking()
            .FirstOrDefaultAsync(p => p.CompanyId == companyId && p.Name == name, ct);
        return row?.Value;
    }

    /// <summary>
    /// Folds a late sale into this session's correction record, creating it on
    /// first sight. One accumulating row per (session, original report) so a
    /// device reconnecting in batches updates counters instead of emitting a
    /// row per push.
    /// </summary>
    public async Task RecordLateArrivalAsync(
        int companyId, int sessionId, decimal amount, decimal cashAmount,
        CancellationToken ct = default)
    {
        var correction = await db.ZReportCorrections
            .FirstOrDefaultAsync(c => c.SessionId == sessionId, ct);

        if (correction is null)
        {
            correction = ZReportCorrection.Create(companyId, sessionId, null);
            db.ZReportCorrections.Add(correction);
        }
        correction.AddLateOrder(amount, cashAmount);
    }

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
