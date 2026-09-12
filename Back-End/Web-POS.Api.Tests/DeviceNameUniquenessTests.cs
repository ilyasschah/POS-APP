using Api.Master.Domain;
using Api.Master.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Api.Tests;

/// <summary>
/// A POS name is unique within its account. The name is the terminal's
/// document-number prefix, so two tills sharing one issue colliding numbers
/// offline. Reported live: a reinstalled terminal could take "POS1" while the
/// old POS1 was still registered, and nothing refused it.
///
/// Also pins the account device list: the POS showed only the terminals the
/// signed-in user had a PIN on, while the registry held all of them.
/// </summary>
public class DeviceNameUniquenessTests
{
    private const int CompanyId = 37;
    private static readonly IConfiguration Config = new ConfigurationBuilder().Build();

    /// <summary>A seven-seat account with terminals enrolled through master login.</summary>
    private static async Task<MasterDbFixture> AccountWithAsync(params (string DeviceId, string? Name)[] devices)
    {
        var fx = new MasterDbFixture();
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);
        await svc.ProvisionTenantAsync(CompanyId, "Test company", seatAllowance: 7);
        foreach (var (id, name) in devices)
        {
            var seat = await svc.RegisterOrValidateDeviceAsync(CompanyId, id, name, isInteractiveLogin: true);
            Assert.True(seat.Allowed, $"{id} was not enrolled: {seat.Reason}");
        }
        return fx;
    }

    private static async Task<string?> NameOfAsync(MasterDbFixture fx, string deviceId)
    {
        using var db = fx.NewContext();
        return (await db.Devices.SingleAsync(d => d.DeviceId == deviceId)).DeviceName;
    }

    [Fact]
    public async Task Rename_refuses_a_name_another_terminal_carries()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"), ("POS-b", "POS2"));
        using var db = fx.NewContext();

        var outcome = await new TenantProvisioningService(db, Config).RenameDeviceAsync(CompanyId, "POS-b", "POS1");

        Assert.Equal(DeviceRenameOutcome.NameTaken, outcome);
        Assert.Equal("POS2", await NameOfAsync(fx, "POS-b"));
    }

    [Fact]
    public async Task Names_collide_regardless_of_case()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"), ("POS-b", "POS2"));
        using var db = fx.NewContext();

        var outcome = await new TenantProvisioningService(db, Config).RenameDeviceAsync(CompanyId, "POS-b", "pos1");

        Assert.Equal(DeviceRenameOutcome.NameTaken, outcome);
    }

    [Fact]
    public async Task A_terminal_is_never_in_conflict_with_itself()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);

        Assert.True(await svc.IsDeviceNameAvailableAsync(CompanyId, "POS-a", "POS1"));
        Assert.Equal(DeviceRenameOutcome.Unchanged, await svc.RenameDeviceAsync(CompanyId, "POS-a", "POS1"));
    }

    [Fact]
    public async Task A_free_name_is_available_and_renames()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"), ("POS-b", "POS2"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);

        Assert.True(await svc.IsDeviceNameAvailableAsync(CompanyId, "POS-b", "POS3"));
        Assert.Equal(DeviceRenameOutcome.Renamed, await svc.RenameDeviceAsync(CompanyId, "POS-b", "POS3"));
        Assert.Equal("POS3", await NameOfAsync(fx, "POS-b"));
    }

    [Fact]
    public async Task A_released_terminal_still_holds_its_name()
    {
        // Uninstalled / signed-out tills are released or reaped to 'inactive',
        // never deleted — and one can come back with its old prefix.
        using var fx = await AccountWithAsync(("POS-a", "POS1"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);
        await svc.ReleaseDeviceAsync(CompanyId, "POS-a");

        Assert.False(await svc.IsDeviceNameAvailableAsync(CompanyId, "POS-new", "POS1"));
    }

    [Fact]
    public async Task Revoking_a_terminal_frees_its_name()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);
        Assert.True(await svc.RevokeDeviceAsync(CompanyId, "POS-a"));

        Assert.True(await svc.IsDeviceNameAvailableAsync(CompanyId, "POS-new", "POS1"));
    }

    [Fact]
    public async Task A_legacy_revoked_row_holds_no_name()
    {
        using var fx = await AccountWithAsync();
        using (var seed = fx.NewContext())
        {
            var tenant = await seed.Tenants.SingleAsync(t => t.CompanyId == CompanyId);
            seed.Devices.Add(new DeviceRegistry
            {
                TenantId = tenant.Id,
                CompanyId = CompanyId,
                DeviceId = "POS-old",
                DeviceName = "POS1",
                Status = "revoked",
            });
            await seed.SaveChangesAsync();
        }
        using var db = fx.NewContext();

        Assert.True(await new TenantProvisioningService(db, Config).IsDeviceNameAvailableAsync(CompanyId, "POS-new", "POS1"));
    }

    [Fact]
    public async Task Another_company_s_terminals_do_not_count()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);
        await svc.ProvisionTenantAsync(38, "Other company", seatAllowance: 2);
        await svc.RegisterOrValidateDeviceAsync(38, "POS-x", "POS5", isInteractiveLogin: true);

        Assert.True(await svc.IsDeviceNameAvailableAsync(CompanyId, "POS-b", "POS5"));
    }

    [Fact]
    public async Task Sync_never_adopts_a_name_another_terminal_carries()
    {
        // Login and every sync resend the local name. A till named before the
        // check existed must not push its duplicate in through that path.
        using var fx = await AccountWithAsync(("POS-a", "POS1"), ("POS-b", "POS2"));
        using var db = fx.NewContext();

        var seat = await new TenantProvisioningService(db, Config).RegisterOrValidateDeviceAsync(CompanyId, "POS-b", "POS1");

        Assert.True(seat.Allowed);
        Assert.Equal("POS2", await NameOfAsync(fx, "POS-b"));
    }

    [Fact]
    public async Task Master_login_enrolls_a_duplicate_name_unnamed_instead_of_refusing()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"));
        using var db = fx.NewContext();

        var seat = await new TenantProvisioningService(db, Config)
            .RegisterOrValidateDeviceAsync(CompanyId, "POS-new", "POS1", isInteractiveLogin: true);

        Assert.True(seat.Allowed);
        Assert.Null(await NameOfAsync(fx, "POS-new"));
        Assert.Equal("POS1", await NameOfAsync(fx, "POS-a"));
    }

    [Fact]
    public async Task Account_devices_lists_every_registered_terminal()
    {
        using var fx = await AccountWithAsync(("POS-a", "POS1"), ("POS-b", "POS2"), ("POS-c", "POS terminal"));
        using var db = fx.NewContext();
        var svc = new TenantProvisioningService(db, Config);
        await svc.ReleaseDeviceAsync(CompanyId, "POS-b");

        var result = await svc.GetAccountDevicesAsync(CompanyId);

        Assert.Equal(7, result.SeatAllowance);
        Assert.Equal(2, result.ActiveSeats);
        Assert.Equal(3, result.Devices.Count);
        // Active terminals first; the released one is still listed, last.
        Assert.Equal("POS-b", result.Devices[^1].DeviceId);
        Assert.Equal("inactive", result.Devices[^1].Status);
        // The legacy constant is not a name — the UI falls back to the id.
        Assert.Null(result.Devices.Single(d => d.DeviceId == "POS-c").DeviceName);
    }

    [Fact]
    public async Task Account_devices_for_an_unprovisioned_company_is_empty()
    {
        using var fx = new MasterDbFixture();
        using var db = fx.NewContext();

        var result = await new TenantProvisioningService(db, Config).GetAccountDevicesAsync(999);

        Assert.Empty(result.Devices);
    }
}
