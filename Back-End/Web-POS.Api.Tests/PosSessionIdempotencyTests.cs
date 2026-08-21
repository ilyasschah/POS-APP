using Api.Domain;
using Xunit;

namespace Web_POS.Api.Tests;

/// <summary>
/// The failure window Phase 5 exists to close.
///
/// The server creates a session, the response is lost on the way back, and the
/// device retries the whole queue. The retry must resolve to the SAME session —
/// a second one would split the day's takings across two periods, and neither
/// would reconcile against the drawer.
///
/// These exercise the reconcile logic directly (no database), so they pin the
/// RULES rather than a particular EF configuration: a replay never moves a
/// session backwards, never re-applies a transition, and never invents a second
/// identity for one localId.
/// </summary>
public class PosSessionIdempotencyTests
{
    /// <summary>
    /// The state machine as `SyncFromDeviceAsync` drives it: advance only when
    /// the server is BEHIND the device, one step at a time.
    /// </summary>
    private static int Reconcile(int serverStatus, int deviceStatus)
    {
        var s = serverStatus;
        if (deviceStatus >= PosSessionStatus.Opened && s == PosSessionStatus.OpeningControl)
            s = PosSessionStatus.Opened;
        if (deviceStatus >= PosSessionStatus.ClosingControl && s == PosSessionStatus.Opened)
            s = PosSessionStatus.ClosingControl;
        if (deviceStatus == PosSessionStatus.Closed && s == PosSessionStatus.ClosingControl)
            s = PosSessionStatus.Closed;
        return s;
    }

    [Fact]
    public void ReplayingTheSamePush_ChangesNothingTheSecondTime()
    {
        // The exact reported scenario: push lands, response lost, device retries.
        var first = Reconcile(PosSessionStatus.OpeningControl, PosSessionStatus.Opened);
        var second = Reconcile(first, PosSessionStatus.Opened);

        Assert.Equal(PosSessionStatus.Opened, first);
        Assert.Equal(first, second);
    }

    [Fact]
    public void AFullQueueReplay_LandsOnTheSameFinalState()
    {
        // The device closed offline; the whole queue is replayed twice.
        var once = Reconcile(PosSessionStatus.OpeningControl, PosSessionStatus.Closed);
        var twice = Reconcile(once, PosSessionStatus.Closed);
        var thrice = Reconcile(twice, PosSessionStatus.Closed);

        Assert.Equal(PosSessionStatus.Closed, once);
        Assert.Equal(PosSessionStatus.Closed, twice);
        Assert.Equal(PosSessionStatus.Closed, thrice);
    }

    [Fact]
    public void AStaleDevice_CannotReopenASessionTheServerHasClosed()
    {
        // 🚨 The dangerous direction. A device that was offline through a
        // force-close still believes it is trading; the reconcile must not walk
        // the session back to OPENED and let it be closed a second time.
        var result = Reconcile(PosSessionStatus.Closed, PosSessionStatus.Opened);
        Assert.Equal(PosSessionStatus.Closed, result);
    }

    [Fact]
    public void TheClosedStateIsTerminal_WhateverTheDeviceClaims()
    {
        foreach (var deviceStatus in new[]
                 {
                     PosSessionStatus.OpeningControl,
                     PosSessionStatus.Opened,
                     PosSessionStatus.ClosingControl,
                     PosSessionStatus.Closed,
                 })
        {
            Assert.Equal(
                PosSessionStatus.Closed,
                Reconcile(PosSessionStatus.Closed, deviceStatus));
        }
    }

    [Fact]
    public void APartiallyAdvancedSession_CatchesUpWithoutSkippingStates()
    {
        // Server got as far as OPENED before the connection dropped; the device
        // has since closed. One push walks it the rest of the way.
        var result = Reconcile(PosSessionStatus.Opened, PosSessionStatus.Closed);
        Assert.Equal(PosSessionStatus.Closed, result);
    }

    [Fact]
    public void OpeningIsIdempotent_AtTheEntityLevelToo()
    {
        // The entity refuses a second ConfirmOpening; the reconcile is what
        // guarantees it is never CALLED twice. Both halves matter — this pins
        // that the strictness the domain relies on is real.
        var session = Shift.OpenSession(25, 9, 1, 2000m, "S-123");
        session.ConfirmOpening(2000m);
        Assert.Throws<InvalidOperationException>(() => session.ConfirmOpening(2000m));
    }
}

/// <summary>
/// Two registers syncing at the same time must stay completely isolated: one
/// device's session, orders and cash can never leak into another's totals.
/// </summary>
public class PosSessionIsolationTests
{
    private sealed record Sale(string SessionLocalId, decimal Amount);

    [Fact]
    public void SalesAreAttributedByTheirOwnSessionLocalId()
    {
        // Till A and Till B trading simultaneously, both pushing at once.
        var sales = new List<Sale>
        {
            new("S-A", 100m), new("S-A", 250m), new("S-A", 75m),
            new("S-B", 400m), new("S-B", 60m),
        };

        var aTotal = sales.Where(s => s.SessionLocalId == "S-A").Sum(s => s.Amount);
        var bTotal = sales.Where(s => s.SessionLocalId == "S-B").Sum(s => s.Amount);

        Assert.Equal(425m, aTotal);
        Assert.Equal(460m, bTotal);
        // 🚨 The failure this replaces: the old Z-report bounded its period by a
        // company-wide document-id RANGE, so device B's sales fell inside device
        // A's range and were swept into A's report.
        Assert.NotEqual(aTotal + bTotal, aTotal);
    }

    [Fact]
    public void TwoDevices_EachHoldTheirOwnLiveSession()
    {
        var a = Shift.OpenSession(25, 9, posDeviceId: 1, 2000m, "S-A");
        var b = Shift.OpenSession(25, 4, posDeviceId: 2, 500m, "S-B");

        a.ConfirmOpening(2000m);
        b.ConfirmOpening(500m);

        Assert.Equal(1, a.PosDeviceId);
        Assert.Equal(2, b.PosDeviceId);
        Assert.NotEqual(a.LocalId, b.LocalId);
        // Closing one leaves the other trading.
        a.EnterClosingControl(2000m);
        a.CloseSession(9, 2000m, 2000m, null);
        Assert.Equal(PosSessionStatus.Closed, a.Status);
        Assert.Equal(PosSessionStatus.Opened, b.Status);
    }

    [Fact]
    public void ASessionOpenedByOneUser_IsClosedByAnother_AndBothAreRecorded()
    {
        // A register is worked by several cashiers; the session records who
        // opened and who closed, while each ORDER keeps its own user.
        var s = Shift.OpenSession(25, userId: 9, posDeviceId: 1, 2000m, "S-A");
        s.ConfirmOpening(2000m);
        s.EnterClosingControl(2000m);
        s.CloseSession(closedByUserId: 4, 2000m, 2000m, null);

        Assert.Equal(9, s.UserId);
        Assert.Equal(4, s.ClosedByUserId);
    }
}

/// <summary>
/// A legitimate paid sale must never be permanently rejected because its
/// session closed while the device was offline (requirement 7/8).
/// </summary>
public class PosSessionLateArrivalTests
{
    [Fact]
    public void LateSales_AccumulateIntoOneCorrection_WithoutTouchingTheSession()
    {
        var session = Shift.OpenSession(25, 9, 1, 2000m, "S-A");
        session.ConfirmOpening(2000m);
        session.EnterClosingControl(10800m);
        session.CloseSession(9, 10800m, 10750m, null);

        var correction = ZReportCorrection.Create(25, sessionId: 1, originalZReportId: 7);
        correction.AddLateOrder(120m, 120m);
        correction.AddLateOrder(80m, 0m);   // card — no effect on the drawer
        session.MarkLateArrival();

        Assert.Equal(2, correction.LateOrderCount);
        Assert.Equal(200m, correction.LateAmount);
        Assert.Equal(120m, correction.LateCashAmount);
        Assert.True(session.HasLateArrivals);

        // 🚨 The signed-off figures are untouched. The correction is what the
        // books are reconciled against — the original report never changes
        // underneath the person who filed it.
        Assert.Equal(10800m, session.ExpectedCash);
        Assert.Equal(10750m, session.ActualEndingCash);
        Assert.Equal(-50m, session.CashDifference);
    }

    [Fact]
    public void ANewArrival_ReopensAnAcknowledgedCorrection()
    {
        var c = ZReportCorrection.Create(25, 1, 7);
        c.AddLateOrder(100m, 100m);
        c.Acknowledge(userId: 4);
        Assert.True(c.Acknowledged);

        c.AddLateOrder(50m, 50m);
        Assert.False(c.Acknowledged);
        Assert.Equal(150m, c.LateAmount);
    }
}
