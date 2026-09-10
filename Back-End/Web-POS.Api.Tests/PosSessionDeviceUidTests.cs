using Api.DataBase;
using Api.Domain;
using Api.Repository;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Every session this API hands out must say which REGISTER it belongs to.
///
/// <para>🚨 `PosSessionDto.PosDeviceUid` is read from a NAVIGATION property
/// (<c>s.PosDevice?.DeviceUid</c>). EF does not lazy-load here, so a query that
/// forgets <c>.Include(s =&gt; s.PosDevice)</c> does not fail — it quietly ships
/// <c>posDeviceUid: null</c>, a session that belongs to no register as far as any
/// client can tell.</para>
///
/// <para>That field is not decoration: a second terminal decides whether it is
/// looking at ITS OWN till by matching this uid (<c>_liveSessionFor</c> in
/// <c>session_provider.dart</c>), and a null makes the shared-register hand-off —
/// "this register is already open, sell in this session" — impossible to offer.
/// <c>/PosSession/History</c> loaded the device; <c>Current</c>, <c>GetByLocalId</c>
/// and <c>GetSession</c> did not.</para>
///
/// <para>Runs on SQLite: the Include is provider-independent, and what is under
/// test is the shape of the query, not SQL Server's dialect.</para>
/// </summary>
public class PosSessionDeviceUidTests : IDisposable
{
    private const int CompanyId = 37;
    private const int UserId = 22;
    private const string RegisterUid = "POS-shared-register";

    private readonly SqliteConnection _connection;
    private readonly AppDbContext _db;
    private readonly PosSessionRepository _repo;
    private readonly int _deviceId;

    public PosSessionDeviceUidTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AppDbContext(
            new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_connection).Options);
        _db.Database.EnsureCreated();

        var device = PosDevice.Create(CompanyId, RegisterUid, "POS1");
        _db.PosDevices.Add(device);
        _db.SaveChanges();
        _deviceId = device.Id;

        _db.Shifts.Add(Shift.OpenSession(
            companyId: CompanyId, userId: UserId, posDeviceId: _deviceId,
            openingCash: 200m, localId: "session-local-1"));
        _db.SaveChanges();

        // Everything below re-reads through the repository, so a nav that only
        // resolves because the entity is still tracked cannot pass for an Include.
        _db.ChangeTracker.Clear();

        _repo = new PosSessionRepository(_db);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    [Fact]
    public async Task The_live_session_for_a_register_knows_its_register()
    {
        // This is what /PosSession/Current answers with, and it came back null.
        var session = await _repo.GetLiveForDeviceAsync(_deviceId);

        Assert.NotNull(session);
        Assert.NotNull(session!.PosDevice);
        Assert.Equal(RegisterUid, session.PosDevice!.DeviceUid);
    }

    [Fact]
    public async Task A_session_looked_up_by_localId_knows_its_register()
    {
        // The reply to an offline session's push — the one a device reads back
        // to learn what the server made of the session it just sent.
        var session = await _repo.GetByLocalIdAsync(CompanyId, "session-local-1");

        Assert.NotNull(session);
        Assert.Equal(RegisterUid, session!.PosDevice?.DeviceUid);
    }

    [Fact]
    public async Task A_session_looked_up_by_id_knows_its_register()
    {
        var expected = await _repo.GetByLocalIdAsync(CompanyId, "session-local-1");

        var session = await _repo.GetSessionAsync(CompanyId, expected!.Id);

        Assert.NotNull(session);
        Assert.Equal(RegisterUid, session!.PosDevice?.DeviceUid);
    }

    [Fact]
    public async Task Every_live_session_in_the_picker_knows_its_register()
    {
        // The register picker shows what a terminal would be JOINING; a null uid
        // there is a register the operator cannot be matched to.
        var live = await _repo.GetLiveSessionsAsync(CompanyId);

        Assert.NotEmpty(live);
        Assert.All(live, s => Assert.Equal(RegisterUid, s.PosDevice?.DeviceUid));
    }

    [Fact]
    public async Task The_history_list_still_knows_its_register()
    {
        // This one was already correct. Pinned so the fix to the others cannot be
        // "solved" later by removing the Include that was right all along.
        var history = await _repo.GetHistoryAsync(CompanyId, posDeviceId: null, take: 10);

        Assert.NotEmpty(history);
        Assert.All(history, s => Assert.Equal(RegisterUid, s.PosDevice?.DeviceUid));
    }
}
