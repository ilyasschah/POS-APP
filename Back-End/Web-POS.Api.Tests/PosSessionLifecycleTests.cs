using Api.Domain;
using Xunit;

namespace Web_POS.Api.Tests;

/// <summary>
/// The POS session state machine, tested on the entity itself.
///
/// These are the rules money depends on: a session cannot be closed twice, a
/// closed one cannot reopen, and selling is only legal in exactly one state.
/// Kept at the domain level deliberately — the transitions are pure and testing
/// them here means they hold no matter which service or endpoint calls them.
/// </summary>
public class PosSessionLifecycleTests
{
    private static Shift OpenSession(decimal openingCash = 2000m) =>
        Shift.OpenSession(
            companyId: 25, userId: 9, posDeviceId: 1,
            openingCash: openingCash, localId: "sess-local-1");

    // ── Status numbering ──────────────────────────────────────────────────────

    [Fact]
    public void SessionStatuses_DoNotCollideWithAttendanceShiftStatuses()
    {
        // 🚨 The whole reason sessions start at 10. Attendance shifts in the SAME
        // table use 0 = Open / 1 = Closed; if a session could be 1, every
        // existing `WHERE Status = 1` would silently start matching a register
        // that is trading right now.
        Assert.True(PosSessionStatus.OpeningControl >= 10);
        Assert.DoesNotContain(0, PosSessionStatus.Live);
        Assert.DoesNotContain(1, PosSessionStatus.Live);
        Assert.NotEqual(1, PosSessionStatus.Closed);
    }

    [Fact]
    public void ClosingControl_CountsAsLive()
    {
        // A half-closed register is still that register's session. If it did not
        // count as live, a second session could open beside it and the two would
        // share the day's takings.
        Assert.Contains(PosSessionStatus.ClosingControl, PosSessionStatus.Live);
        Assert.False(PosSessionStatus.IsLive(PosSessionStatus.Closed));
    }

    // ── Opening ───────────────────────────────────────────────────────────────

    [Fact]
    public void OpenSession_StartsInOpeningControl_NotSelling()
    {
        var s = OpenSession();
        Assert.Equal(PosSessionStatus.OpeningControl, s.Status);
        Assert.Equal(1, s.PosDeviceId);
        Assert.Equal("sess-local-1", s.LocalId);
    }

    [Fact]
    public void ConfirmOpening_MovesToOpened_AndStoresTheCountedFloat()
    {
        var s = OpenSession(2000m);
        s.ConfirmOpening(1950m);

        Assert.Equal(PosSessionStatus.Opened, s.Status);
        // The COUNTED float wins over the expected one — that is the point of
        // opening control, and every later expected-cash figure builds on it.
        Assert.Equal(1950m, s.StartingCash);
    }

    [Fact]
    public void ConfirmOpening_IsRejectedOutsideOpeningControl()
    {
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        Assert.Throws<InvalidOperationException>(() => s.ConfirmOpening(2000m));
    }

    [Fact]
    public void OpenSession_RejectsANegativeFloat()
        => Assert.Throws<ArgumentException>(() =>
            Shift.OpenSession(25, 9, 1, -1m, null));

    // ── Closing ───────────────────────────────────────────────────────────────

    [Fact]
    public void Close_RequiresClosingControlFirst()
    {
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        // Straight from OPENED — the drawer was never frozen for counting.
        Assert.Throws<InvalidOperationException>(
            () => s.CloseSession(9, expectedCash: 10800m, countedCash: 10750m, closingNote: null));
    }

    [Fact]
    public void Close_RecordsTheDifference_UsingTheWorkedExample()
    {
        // 2,000 opening + 8,500 cash sales + 500 in − 200 out = 10,800 expected.
        // Counted 10,750 ⇒ −50.
        var s = OpenSession(2000m);
        s.ConfirmOpening(2000m);
        s.EnterClosingControl(10800m);
        s.CloseSession(9, expectedCash: 10800m, countedCash: 10750m, closingNote: "short");

        Assert.Equal(PosSessionStatus.Closed, s.Status);
        Assert.Equal(10800m, s.ExpectedCash);
        Assert.Equal(10750m, s.ActualEndingCash);
        Assert.Equal(-50m, s.CashDifference);
        Assert.Equal("short", s.ClosingNote);
        Assert.Equal(9, s.ClosedByUserId);
        Assert.NotNull(s.ClosedAt);
        Assert.False(s.ForceClosed);
    }

    [Fact]
    public void EnterClosingControl_FreezesTheExpectedFigure()
    {
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        s.EnterClosingControl(10800m);

        Assert.Equal(PosSessionStatus.ClosingControl, s.Status);
        Assert.Equal(10800m, s.ExpectedCash);
        // Selling has stopped here, not at CLOSED — a sale landing between the
        // calculation and the count would invalidate what the cashier signs.
        Assert.False(s.Status == PosSessionStatus.Opened);
    }

    [Fact]
    public void AClosedSession_CannotBeClosedAgain()
    {
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        s.EnterClosingControl(10800m);
        s.CloseSession(9, 10800m, 10800m, null);

        Assert.Throws<InvalidOperationException>(() => s.CloseSession(9, 10800m, 10800m, null));
        Assert.Throws<InvalidOperationException>(() => s.EnterClosingControl(1m));
        Assert.Throws<InvalidOperationException>(() => s.ForceClose(1, "try again"));
    }

    // ── Force close ───────────────────────────────────────────────────────────

    [Fact]
    public void ForceClose_SkipsClosingControl_AndRecordsTheAudit()
    {
        // The register is unreachable, so nobody can count its drawer — that is
        // exactly why no count is required here.
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        s.ForceClose(closedByUserId: 1, reason: "Terminal stolen");

        Assert.Equal(PosSessionStatus.Closed, s.Status);
        Assert.True(s.ForceClosed);
        Assert.Equal(1, s.ForceClosedByUserId);
        Assert.Equal("Terminal stolen", s.ForceCloseReason);
        Assert.Null(s.ActualEndingCash);
    }

    [Fact]
    public void ForceClose_DemandsAReason()
    {
        var s = OpenSession();
        Assert.Throws<InvalidOperationException>(() => s.ForceClose(1, "   "));
    }

    [Fact]
    public void MarkLateArrival_FlagsWithoutTouchingTheMoney()
    {
        // A sale arriving after the close must never rewrite the figures that
        // were signed off; it only raises the flag that a correction exists.
        var s = OpenSession();
        s.ConfirmOpening(2000m);
        s.EnterClosingControl(10800m);
        s.CloseSession(9, 10800m, 10750m, null);

        s.MarkLateArrival();

        Assert.True(s.HasLateArrivals);
        Assert.Equal(10800m, s.ExpectedCash);
        Assert.Equal(10750m, s.ActualEndingCash);
        Assert.Equal(-50m, s.CashDifference);
    }

    // ── Attendance shifts are untouched ───────────────────────────────────────

    [Fact]
    public void AttendanceShifts_KeepTheirLegacyBehaviourExactly()
    {
        // The pre-existing clock-in path. No device, legacy 0/1 statuses, and
        // none of the session transitions apply to it.
        var shift = Shift.Create(companyId: 25, userId: 9, startingCash: 0m);
        Assert.Null(shift.PosDeviceId);
        Assert.Equal(0, shift.Status);

        shift.Close(actualEndingCash: 120m);
        Assert.Equal(1, shift.Status);
        Assert.Equal(120m, shift.ActualEndingCash);
        Assert.NotNull(shift.ClosedAt);
        Assert.False(shift.ForceClosed);
    }
}

/// <summary>
/// The cash-difference tolerance rule (10 DH by default, per company).
/// Pure arithmetic, kept separate so it reads as the business rule it is.
/// </summary>
public class PosSessionToleranceTests
{
    private static bool NeedsManager(decimal expected, decimal counted, decimal tolerance)
        => Math.Abs(counted - expected) > tolerance;

    [Theory]
    [InlineData(10800, 10800, false)]  // exact
    [InlineData(10800, 10795, false)]  // 5 short — within tolerance
    [InlineData(10800, 10810, false)]  // 10 over — exactly at the limit
    [InlineData(10800, 10750, true)]   // 50 short — the worked example
    [InlineData(10800, 10815, true)]   // 15 over
    public void TenDirhamTolerance(decimal expected, decimal counted, bool needsManager)
        => Assert.Equal(needsManager, NeedsManager(expected, counted, 10m));

    [Fact]
    public void AZeroToleranceMakesEveryDiscrepancyAManagerDecision()
    {
        Assert.True(NeedsManager(100m, 99.99m, 0m));
        Assert.False(NeedsManager(100m, 100m, 0m));
    }
}
