using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services;

/// <summary>
/// POS session lifecycle and the rules around it. The server is the authority
/// for session STATE; the device is the authority for what it alone knows
/// (unsynced sales, parked orders) — see <see cref="GetCloseBlockersAsync"/>.
///
/// Business failures throw <see cref="InvalidOperationException"/>, which the
/// existing middleware maps to a 400 with the message — the same contract the
/// tax and checkout services already rely on, so the client's
/// `_resolveRejection` handles them without new plumbing.
/// </summary>
public class PosSessionService(
    PosSessionRepository repo,
    ZReportService zReports,
    ILogger<PosSessionService> logger)
{
    /// <summary>Company setting: cash difference a cashier may close through alone.</summary>
    public const string MaxCashDifferenceSetting = "PosSession.MaxCashDifference";

    /// <summary>
    /// Company setting: explicit comma-separated PaymentType ids that come out
    /// of the cash drawer. Optional — see <see cref="IsCashMethodAsync"/> for
    /// why a fallback is needed and what it is.
    /// </summary>
    public const string CashPaymentTypeIdsSetting = "PosSession.CashPaymentTypeIds";

    // ── Registers ─────────────────────────────────────────────────────────────

    /// <summary>
    /// Every register in the company, each with the session it is running.
    ///
    /// 🚨 A REGISTER is not a terminal. It is Odoo's `pos.config`: one named
    /// till, one drawer, one session at a time — and any number of terminals may
    /// be working it at once. The rows live in `PosDevice` because that table
    /// was originally keyed by the terminal's own GUID, which is precisely why
    /// two devices could never share a session: each one quietly created a
    /// register of its own on first open.
    /// </summary>
    public async Task<List<PosRegisterDto>> GetRegistersAsync(
        int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) throw new InvalidOperationException("Company ID is required.");

        var registers = await repo.GetRegistersAsync(companyId, ct);
        var live = await repo.GetLiveSessionsAsync(companyId, ct);
        var liveByDevice = live
            .Where(s => s.PosDeviceId is not null)
            .GroupBy(s => s.PosDeviceId!.Value)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(s => s.OpenedAt).First());

        return registers.Select(d =>
        {
            liveByDevice.TryGetValue(d.Id, out var session);
            return new PosRegisterDto
            {
                Id = d.Id,
                Uid = d.DeviceUid,
                Name = d.Name,
                LastSeenAt = d.LastSeenAt,
                LiveSessionId = session?.Id,
                LiveSessionStatus = session?.Status,
            };
        }).ToList();
    }

    /// <summary>
    /// Creates a register, or renames an existing one. Idempotent on
    /// <paramref name="uid"/> — the same contract as the open path, because the
    /// picker and an offline open can both reach the same register first.
    /// </summary>
    public async Task<PosRegisterDto> UpsertRegisterAsync(
        int companyId, string uid, string? name, CancellationToken ct = default)
    {
        if (companyId <= 0) throw new InvalidOperationException("Company ID is required.");
        if (string.IsNullOrWhiteSpace(uid))
            throw new InvalidOperationException("A register id is required.");

        var device = await repo.GetOrCreateDeviceAsync(companyId, uid, name, ct);
        await repo.SaveChangesAsync(ct);

        var live = await repo.GetLiveForDeviceAsync(device.Id, ct);
        return new PosRegisterDto
        {
            Id = device.Id,
            Uid = device.DeviceUid,
            Name = device.Name,
            LastSeenAt = device.LastSeenAt,
            LiveSessionId = live?.Id,
            LiveSessionStatus = live?.Status,
        };
    }

    // ── Open ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Opens a session on a register, in OPENING_CONTROL.
    ///
    /// 🚨 Idempotent on <paramref name="localId"/>. A device that opened a
    /// session offline re-pushes it until it lands, and it cannot know whether
    /// an earlier attempt reached us — so the same localId must return the same
    /// session rather than create a second one. This is the same contract the
    /// order push relies on (backlog item 33).
    /// </summary>
    public async Task<Shift> OpenAsync(
        int companyId,
        int userId,
        string deviceUid,
        string? deviceName,
        decimal openingCash,
        string? localId,
        DateTime? openedAt,
        CancellationToken ct = default)
    {
        if (companyId <= 0) throw new InvalidOperationException("Company ID is required.");
        if (userId <= 0) throw new InvalidOperationException("User ID is required.");
        if (string.IsNullOrWhiteSpace(deviceUid))
            throw new InvalidOperationException("Device ID is required to open a session.");

        // Retry of a push we already accepted → hand back the same session.
        if (!string.IsNullOrWhiteSpace(localId))
        {
            var existing = await repo.GetByLocalIdAsync(companyId, localId.Trim(), ct);
            if (existing is not null)
            {
                logger.LogInformation(
                    "Session open is a retry of {LocalId} -> session {Id}; returning the existing row.",
                    localId, existing.Id);
                return existing;
            }
        }

        var device = await repo.GetOrCreateDeviceAsync(companyId, deviceUid, deviceName, ct);
        await repo.SaveChangesAsync(ct); // the device needs an Id before the session references it

        // One live session per register. Checked here AND enforced by the
        // partial unique index in the database, because two requests can race.
        // One live session per REGISTER — unchanged, and now the rule it always
        // meant to be. A second terminal working the same till must JOIN this
        // session, never open a parallel one: two sessions on one drawer means
        // two Z-reports for one set of cash.
        var live = await repo.GetLiveForDeviceAsync(device.Id, ct);
        if (live is not null)
        {
            throw new InvalidOperationException(
                $"This register already has an open session (#{live.Id}, " +
                $"{PosSessionStatus.Name(live.Status)}). Continue selling in it, or close it first.");
        }

        var session = Shift.OpenSession(companyId, userId, device.Id, openingCash, localId, openedAt);
        await AddAsync(session, ct);
        logger.LogInformation(
            "Opened POS session {Id} on device {Device} ({Uid}) by user {User}.",
            session.Id, device.Name, device.DeviceUid, userId);
        return session;
    }

    /// <summary>OPENING_CONTROL → OPENED, with the counted opening float.</summary>
    public async Task<Shift> ConfirmOpeningAsync(
        int companyId, int sessionId, decimal countedOpeningCash, CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);
        session.ConfirmOpening(countedOpeningCash);
        await repo.SaveChangesAsync(ct);
        return session;
    }

    /// <summary>The session a register is currently running, if any.</summary>
    public async Task<Shift?> GetLiveForDeviceAsync(
        int companyId, string deviceUid, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(deviceUid)) return null;
        var device = await repo.GetOrCreateDeviceAsync(companyId, deviceUid, null, ct);
        if (device.Id == 0) return null; // brand-new device: nothing can be open on it
        return await repo.GetLiveForDeviceAsync(device.Id, ct);
    }

    // ── Reconciliation ────────────────────────────────────────────────────────

    /// <summary>
    /// The closing figures: per-method expected totals and the expected cash.
    ///
    ///   expected cash = opening + cash payments + cash in − cash out
    ///
    /// Computed here, against the database, and never trusted from the client —
    /// this is the number a cashier is held to.
    /// </summary>
    public async Task<PosSessionSummaryDto> BuildSummaryAsync(
        int companyId, int sessionId, CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);

        var paymentTotals = await repo.GetPaymentTotalsAsync(sessionId, ct);
        var (cashIn, cashOut) = await repo.GetCashMovementTotalsAsync(sessionId, ct);
        var orderCount = await repo.GetOrderCountAsync(sessionId, ct);
        var types = await repo.GetPaymentTypesAsync(companyId, ct);
        var (cashIds, cashConfigured) = await GetCashPaymentTypeIdsAsync(companyId, types, ct);

        var methods = paymentTotals
            .Select(t => new PosSessionMethodDto
            {
                PaymentTypeId = t.PaymentTypeId,
                PaymentTypeName = types.FirstOrDefault(x => x.Id == t.PaymentTypeId)?.Name ?? "?",
                IsCash = cashIds.Contains(t.PaymentTypeId),
                Expected = t.Total,
            })
            .OrderByDescending(m => m.IsCash)
            .ThenBy(m => m.PaymentTypeName)
            .ToList();

        var cashPayments = methods.Where(m => m.IsCash).Sum(m => m.Expected);
        var expectedCash = session.StartingCash + cashPayments + cashIn - cashOut;

        return new PosSessionSummaryDto
        {
            SessionId = session.Id,
            Status = session.Status,
            StatusName = PosSessionStatus.Name(session.Status),
            OpenedAt = session.OpenedAt,
            OpenedByUserId = session.UserId,
            OrderCount = orderCount,
            OpeningCash = session.StartingCash,
            CashPayments = cashPayments,
            CashIn = cashIn,
            CashOut = cashOut,
            ExpectedCash = expectedCash,
            TotalTaken = methods.Sum(m => m.Expected),
            Methods = methods,
            MaxCashDifference = await GetMaxCashDifferenceAsync(companyId, ct),
            CashMethodsConfigured = cashConfigured,
        };
    }

    /// <summary>OPENED → CLOSING_CONTROL. Selling stops here, not at CLOSED.</summary>
    public async Task<PosSessionSummaryDto> EnterClosingControlAsync(
        int companyId, int sessionId, CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);
        var summary = await BuildSummaryAsync(companyId, sessionId, ct);
        session.EnterClosingControl(summary.ExpectedCash);
        await repo.SaveChangesAsync(ct);
        summary.Status = session.Status;
        summary.StatusName = PosSessionStatus.Name(session.Status);
        return summary;
    }

    /// <summary>
    /// Reasons the SERVER can see that should stop a close.
    ///
    /// ⚠️ Deliberately not the whole list. The device is the only thing that
    /// knows about sales still sitting in its push queue and about orders parked
    /// locally — the user's own requirement §14. The client adds those; this is
    /// the half the server can answer.
    /// </summary>
    public async Task<List<string>> GetCloseBlockersAsync(
        int companyId, int sessionId, CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);
        var blockers = new List<string>();

        if (session.Status == PosSessionStatus.Closed)
            blockers.Add("This session is already closed.");

        return blockers;
    }

    /// <summary>
    /// CLOSING_CONTROL → CLOSED.
    ///
    /// A difference beyond the company's tolerance needs a manager: the cashier
    /// cannot sign off their own shortfall. The authorising user is required to
    /// be an admin and is recorded.
    /// </summary>
    public async Task<Shift> CloseAsync(
        int companyId,
        int sessionId,
        int closedByUserId,
        decimal countedCash,
        IReadOnlyList<PosSessionCountInput>? counts,
        string? closingNote,
        bool managerAuthorised,
        CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);
        var summary = await BuildSummaryAsync(companyId, sessionId, ct);

        var difference = countedCash - summary.ExpectedCash;
        var tolerance = summary.MaxCashDifference;
        if (Math.Abs(difference) > tolerance && !managerAuthorised)
        {
            throw new InvalidOperationException(
                $"Cash difference of {difference:0.00} exceeds the allowed {tolerance:0.00}. " +
                "Manager authorisation is required to close this session.");
        }

        // Persist what the cashier actually counted, per method — the evidence
        // that the drawer was checked, separate from what the report says.
        await repo.ClearCountsAsync(sessionId, ct);
        foreach (var m in summary.Methods)
        {
            var counted = counts?.FirstOrDefault(c => c.PaymentTypeId == m.PaymentTypeId)?.Counted;
            // Cash is counted physically; if the caller sent nothing for it, the
            // drawer total it did send is the count.
            if (counted is null && m.IsCash) counted = countedCash;
            repo.AddCount(PosSessionPaymentCount.Create(
                companyId, sessionId, m.PaymentTypeId, m.Expected, counted));
        }

        session.CloseSession(closedByUserId, summary.ExpectedCash, countedCash, closingNote);
        await repo.SaveChangesAsync(ct);

        // Closing a session IS taking its Z-report — one act, by decision. The
        // report is bounded by THIS session, so two registers closing the same
        // evening cannot contaminate each other (the defect the old document-id
        // range had). Best-effort: a report failure must not leave a counted,
        // signed-off drawer stuck in CLOSING_CONTROL with no way out.
        try
        {
            await zReports.GenerateForSessionAsync(companyId, closedByUserId, sessionId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Session {Id} closed but its Z-report failed. The session is closed; " +
                "regenerate the report from the session screen.", sessionId);
        }

        logger.LogInformation(
            "Closed POS session {Id}: expected {Expected:0.00}, counted {Counted:0.00}, difference {Diff:0.00}.",
            session.Id, summary.ExpectedCash, countedCash, difference);
        return session;
    }

    /// <summary>
    /// Admin-only close for a register that cannot close itself.
    ///
    /// 🚨 Does NOT compute a count — the whole reason to force-close is that the
    /// device is unreachable, so nobody can count its drawer. What it records is
    /// who did it and why, and the session stays flagged for the sales that may
    /// still arrive from it.
    /// </summary>
    public async Task<Shift> ForceCloseAsync(
        int companyId, int sessionId, int adminUserId, string reason, CancellationToken ct = default)
    {
        var session = await RequireSessionAsync(companyId, sessionId, ct);
        if (string.IsNullOrWhiteSpace(reason))
            throw new InvalidOperationException("A force-close requires a reason.");

        session.ForceClose(adminUserId, reason);
        await repo.SaveChangesAsync(ct);

        logger.LogWarning(
            "FORCE-CLOSED POS session {Id} by user {User}. Reason: {Reason}. " +
            "Sales may still arrive from this device.",
            session.Id, adminUserId, reason);
        return session;
    }

    // ── Offline sync ──────────────────────────────────────────────────────────

    /// <summary>
    /// Reconciles a device's session state into the server, idempotently. This
    /// is what the offline pusher calls, and it may be called any number of
    /// times with the same payload.
    ///
    /// 🚨 The failure this exists for: the server creates the session, the
    /// response is lost on the way back, and the device retries. A second
    /// session must NOT appear. <see cref="OpenAsync"/> already returns the
    /// existing row for a known LocalId, and every transition below is written
    /// as "move it if it is behind", never "apply this transition" — so a
    /// replay of the whole queue is a no-op rather than an error.
    ///
    /// It deliberately does NOT accept the device's cash figures for a close:
    /// expected cash is recomputed here, against this database. The device
    /// supplies what was COUNTED, which only it can know.
    /// </summary>
    public async Task<Shift> SyncFromDeviceAsync(
        int companyId,
        SyncPosSessionRequest request,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.LocalId))
            throw new InvalidOperationException("A session push must carry its LocalId.");

        // Step 1 — make sure it exists. Idempotent on LocalId.
        var session = await OpenAsync(
            companyId, request.UserId, request.DeviceUid, request.DeviceName,
            request.OpeningCash, request.LocalId, request.OpenedAt, ct);

        // Step 2 — advance it to wherever the device says it got to, one step at
        // a time, skipping anything already applied. Never moves BACKWARDS: a
        // session closed on the server stays closed even if a stale device still
        // believes it is trading.
        if (request.Status >= PosSessionStatus.Opened &&
            session.Status == PosSessionStatus.OpeningControl)
        {
            session.ConfirmOpening(request.OpeningCash, request.OpeningNote);
        }

        if (request.Status >= PosSessionStatus.ClosingControl &&
            session.Status == PosSessionStatus.Opened)
        {
            var interim = await BuildSummaryAsync(companyId, session.Id, ct);
            session.EnterClosingControl(interim.ExpectedCash);
        }

        if (request.Status == PosSessionStatus.Closed &&
            session.Status == PosSessionStatus.ClosingControl)
        {
            var summary = await BuildSummaryAsync(companyId, session.Id, ct);
            var counted = request.CountedCash ?? summary.ExpectedCash;

            // The tolerance is NOT enforced on a replay: the close already
            // happened on the device, in front of the cashier. Refusing it here
            // would strand a closed register in a half-open state on the server
            // with no way to finish. The difference is recorded and visible.
            session.CloseSession(
                request.ClosedByUserId ?? request.UserId,
                summary.ExpectedCash, counted, request.ClosingNote);

            await PersistCountsAsync(companyId, session.Id, summary, request.Counts, counted, ct);
        }

        await repo.SaveChangesAsync(ct);
        return session;
    }

    private async Task PersistCountsAsync(
        int companyId,
        int sessionId,
        PosSessionSummaryDto summary,
        IReadOnlyList<PosSessionCountInput>? counts,
        decimal countedCash,
        CancellationToken ct)
    {
        await repo.ClearCountsAsync(sessionId, ct);
        foreach (var m in summary.Methods)
        {
            var counted = counts?.FirstOrDefault(c => c.PaymentTypeId == m.PaymentTypeId)?.Counted;
            if (counted is null && m.IsCash) counted = countedCash;
            repo.AddCount(PosSessionPaymentCount.Create(
                companyId, sessionId, m.PaymentTypeId, m.Expected, counted));
        }
    }

    /// <summary>
    /// Attaches a synced sale to its session, and flags it when the session has
    /// already closed.
    ///
    /// 🚨 A late sale is ACCEPTED. It keeps its original session, is never moved
    /// to the next one, and never rewrites the closed session's figures — the
    /// difference is carried by a <see cref="ZReportCorrection"/> instead. The
    /// alternative, rejecting it, is how a paid sale becomes permanently
    /// unsyncable, which is the exact failure backlog item 33 was about.
    ///
    /// Returns the session id to stamp, or null when the device sent no session
    /// (pre-session rows, and anything created while the guard is still off).
    /// </summary>
    public async Task<(int? SessionId, bool Late)> AttachSaleAsync(
        int companyId, string? sessionLocalId, decimal amount, decimal cashAmount,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(sessionLocalId)) return (null, false);

        var session = await repo.GetByLocalIdAsync(companyId, sessionLocalId.Trim(), ct);
        if (session is null)
        {
            // The session has not reached us yet — ordering should prevent this,
            // but a sale must never be lost to a race. Bank it unattached rather
            // than refuse it; the session link is reporting metadata, not money.
            logger.LogWarning(
                "Sale references unknown session {LocalId}; banking it unattached.",
                sessionLocalId);
            return (null, false);
        }

        if (session.Status != PosSessionStatus.Closed) return (session.Id, false);

        session.MarkLateArrival();
        await repo.RecordLateArrivalAsync(companyId, session.Id, amount, cashAmount, ct);
        logger.LogWarning(
            "LATE ARRIVAL: sale for CLOSED session {Id} ({Amount:0.00}). " +
            "Kept on its original session; a correction record was raised.",
            session.Id, amount);
        return (session.Id, true);
    }

    // ── Guards used by other services (wired in a later phase) ───────────────

    /// <summary>
    /// Resolves a client session localId to a live session, for the sale /
    /// refund / cash-movement guard.
    ///
    /// ⚠️ Returns null rather than throwing when the id is unknown or the
    /// session is closed. The gate is deliberately fail-OPEN at this level: a
    /// register that cannot resolve its session must not be prevented from
    /// trading, because a bad session state would otherwise take a shop offline
    /// completely. The caller decides how strict to be, and the late-arrival
    /// path (Phase 10) is what keeps a sale against a closed session safe.
    /// </summary>
    public async Task<Shift?> ResolveOpenSessionAsync(
        int companyId, string? sessionLocalId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(sessionLocalId)) return null;
        var session = await repo.GetByLocalIdAsync(companyId, sessionLocalId.Trim(), ct);
        if (session is null) return null;
        return session.Status == PosSessionStatus.Opened ? session : null;
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private async Task<Shift> RequireSessionAsync(int companyId, int sessionId, CancellationToken ct)
    {
        var session = await repo.GetSessionAsync(companyId, sessionId, ct);
        if (session is null)
            throw new InvalidOperationException($"POS session {sessionId} was not found.");
        return session;
    }

    private async Task AddAsync(Shift session, CancellationToken ct)
    {
        repo.AddSession(session);
        await repo.SaveChangesAsync(ct);
    }

    private async Task<decimal> GetMaxCashDifferenceAsync(int companyId, CancellationToken ct)
    {
        var raw = await repo.GetSettingAsync(companyId, MaxCashDifferenceSetting, ct);
        if (decimal.TryParse(raw, System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out var v) && v >= 0)
            return v;
        return 10m; // matches the seeded default
    }

    /// <summary>
    /// Which payment methods come out of the cash drawer.
    ///
    /// 🚨 <see cref="CashPaymentTypeIdsSetting"/> is the AUTHORITATIVE source for
    /// cash accounting. When it is set, it is used verbatim and nothing is
    /// inferred — so a method the company has not listed (Credit, vouchers, a
    /// wallet) can never be counted as drawer cash, whatever its flags happen to
    /// say.
    ///
    /// The `IsChangeAllowed` inference below is a DEVELOPMENT / legacy fallback
    /// for a company that has not configured the setting yet, not a production
    /// source of truth. It exists only so an unconfigured company still gets a
    /// plausible closing screen instead of an expected-cash of zero. There is no
    /// `IsCash` flag to use, and `OpenCashDrawer` is worse than useless here —
    /// the default seed sets it true for BOTH "Espèces" and "Credit", so relying
    /// on it would count credit sales as cash in the drawer.
    ///
    /// <paramref name="configured"/> reports which of the two was used, so the
    /// closing screen can tell the operator their cash methods are guessed.
    /// </summary>
    private async Task<(HashSet<int> Ids, bool Configured)> GetCashPaymentTypeIdsAsync(
        int companyId, List<PaymentType> types, CancellationToken ct)
    {
        var raw = await repo.GetSettingAsync(companyId, CashPaymentTypeIdsSetting, ct);
        if (!string.IsNullOrWhiteSpace(raw))
        {
            var ids = raw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(s => int.TryParse(s, out var i) ? i : 0)
                .Where(i => i > 0)
                .ToHashSet();

            // A setting that is present but yields nothing usable is a
            // configuration error, not an instruction to count zero cash — fall
            // through to the inference and say so, rather than silently
            // reporting an expected cash of just the opening float.
            if (ids.Count > 0) return (ids, true);

            logger.LogWarning(
                "Company {Company}: {Setting} is set to '{Raw}' but contains no valid ids; " +
                "falling back to the IsChangeAllowed inference.",
                companyId, CashPaymentTypeIdsSetting, raw);
        }

        logger.LogWarning(
            "Company {Company} has no {Setting}; cash payment methods are INFERRED from " +
            "IsChangeAllowed. Configure the setting before relying on cash reconciliation.",
            companyId, CashPaymentTypeIdsSetting);

        return (types.Where(t => t.IsChangeAllowed).Select(t => t.Id).ToHashSet(), false);
    }

    public Task<List<Shift>> GetHistoryAsync(
        int companyId, int? posDeviceId, int take, CancellationToken ct = default) =>
        repo.GetHistoryAsync(companyId, posDeviceId, take <= 0 ? 50 : take, ct);
}
