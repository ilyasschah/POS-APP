using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

/// <summary>
/// A register: one install of the POS app, in COMPANY-database terms.
///
/// 🚨 Why this exists at all, given <c>Master.Domain.DeviceRegistry</c> already
/// identifies every terminal: that table lives in the CONTROL-PLANE database
/// (it carries a TenantId and drives licensing + seat enforcement), so a
/// company-database foreign key to it is impossible. Without this projection a
/// session could only store a bare GUID string — no referential integrity, and
/// every report that wanted a device name would have to join across databases
/// by hand.
///
/// It is deliberately NOT a second source of truth. <see cref="DeviceUid"/> is
/// the same GUID the device already holds in secure storage and already sends
/// as <c>X-Device-Id</c>, so the row is an upsert keyed on an identity that
/// exists first elsewhere. Nothing creates a PosDevice by hand.
///
/// <see cref="Name"/> mirrors the device-local <c>pos.device.name</c> ("POS1"),
/// which already prefixes every document number this terminal issues
/// (<c>POS1-200-000014</c>) — so a session report can say which register a
/// number came from without parsing the number.
/// </summary>
[Table("PosDevice")]
public class PosDevice : ISyncableEntity
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }

    /// <summary>
    /// The terminal's stable GUID — `AuthStorage.getOrCreateDeviceId()` on the
    /// client, `DeviceRegistry.DeviceId` in the control plane. Unique per
    /// company; a reinstall that keeps its identity keeps its device row.
    /// </summary>
    [Required]
    [MaxLength(128)]
    public string DeviceUid { get; private set; } = default!;

    /// <summary>Display name / document-number prefix, e.g. "POS1".</summary>
    [MaxLength(64)]
    public string? Name { get; private set; }

    public DateTime FirstSeenAt { get; private set; }
    public DateTime LastSeenAt { get; private set; }

    public DateTime LastModified { get; set; } = DateTime.UtcNow;

    public PosDevice() { }

    private PosDevice(int companyId, string deviceUid, string? name)
    {
        CompanyId = companyId;
        DeviceUid = deviceUid;
        Name = name;
        FirstSeenAt = DateTime.UtcNow;
        LastSeenAt = DateTime.UtcNow;
    }

    public static PosDevice Create(int companyId, string deviceUid, string? name)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (string.IsNullOrWhiteSpace(deviceUid))
            throw new ArgumentException("DeviceUid cannot be empty", nameof(deviceUid));
        return new PosDevice(companyId, deviceUid.Trim(), Clean(name));
    }

    /// <summary>
    /// Refreshes the display name and the last-seen stamp on an existing row.
    /// The name can legitimately change — the operator renames the terminal in
    /// Settings — so it is updated rather than treated as immutable.
    /// </summary>
    public void Touch(string? name)
    {
        var cleaned = Clean(name);
        if (!string.IsNullOrEmpty(cleaned)) Name = cleaned;
        LastSeenAt = DateTime.UtcNow;
    }

    private static string? Clean(string? name)
    {
        var trimmed = name?.Trim();
        if (string.IsNullOrEmpty(trimmed)) return null;
        return trimmed.Length > 64 ? trimmed[..64] : trimmed;
    }
}
