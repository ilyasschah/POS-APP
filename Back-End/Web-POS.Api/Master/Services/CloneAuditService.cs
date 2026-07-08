using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Master.Services
{
    /// <summary>Result of auditing a sync batch for clone / duplication (Pillar 5).</summary>
    public record CloneAuditResult(int Recorded, IReadOnlyList<string> FlaggedTxnIds)
    {
        public bool HasAnomalies => FlaggedTxnIds.Count > 0;
        public static readonly CloneAuditResult Empty = new(0, Array.Empty<string>());
    }

    public interface ICloneAuditService
    {
        /// <summary>
        /// Records each transaction id from a sync batch against the tenant's audit
        /// ledger and flags any that were first reported by a DIFFERENT device — the
        /// signature of a cloned terminal / restored backup. Detection only: never
        /// throws into the sync path (callers wrap best-effort).
        /// </summary>
        Task<CloneAuditResult> RecordAndCheckAsync(
            int companyId, string? deviceId, IEnumerable<string> clientTxnIds, CancellationToken ct = default);

        /// <summary>Flagged duplicate transactions for a tenant, newest first.</summary>
        Task<IReadOnlyList<TransactionAudit>> GetAlertsAsync(int companyId, int take = 50, CancellationToken ct = default);
    }

    public class CloneAuditService : ICloneAuditService
    {
        private readonly MasterDbContext _db;
        public CloneAuditService(MasterDbContext db) => _db = db;

        public async Task<CloneAuditResult> RecordAndCheckAsync(
            int companyId, string? deviceId, IEnumerable<string> clientTxnIds, CancellationToken ct = default)
        {
            // Without a device id we can't attribute origin, so cross-device
            // detection is impossible — skip rather than record noise.
            if (string.IsNullOrWhiteSpace(deviceId)) return CloneAuditResult.Empty;

            var ids = clientTxnIds
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .Distinct()
                .ToList();
            if (ids.Count == 0) return CloneAuditResult.Empty;

            var tenant = await _db.Tenants.AsNoTracking()
                .FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return CloneAuditResult.Empty;

            var existing = await _db.TransactionAudits
                .Where(a => a.TenantId == tenant.Id && ids.Contains(a.ClientTxnId))
                .ToListAsync(ct);
            var byId = existing.ToDictionary(a => a.ClientTxnId);

            var now = DateTime.UtcNow;
            var flagged = new List<string>();
            var recorded = 0;

            foreach (var txnId in ids)
            {
                if (byId.TryGetValue(txnId, out var row))
                {
                    row.SeenCount++;
                    row.LastSeenUtc = now;
                    row.LastDeviceId = deviceId;
                    // Same txn id from a device other than the one that minted it.
                    if (!string.Equals(row.FirstDeviceId, deviceId, StringComparison.Ordinal))
                    {
                        row.IsFlagged = true;
                        row.FlagReason = "cross_device_duplicate";
                        flagged.Add(txnId);
                    }
                }
                else
                {
                    _db.TransactionAudits.Add(new TransactionAudit
                    {
                        TenantId = tenant.Id,
                        CompanyId = companyId,
                        ClientTxnId = txnId,
                        FirstDeviceId = deviceId,
                        LastDeviceId = deviceId,
                        SeenCount = 1,
                        FirstSeenUtc = now,
                        LastSeenUtc = now,
                    });
                    recorded++;
                }
            }

            await _db.SaveChangesAsync(ct);
            return new CloneAuditResult(recorded, flagged);
        }

        public async Task<IReadOnlyList<TransactionAudit>> GetAlertsAsync(int companyId, int take = 50, CancellationToken ct = default)
        {
            return await _db.TransactionAudits.AsNoTracking()
                .Where(a => a.CompanyId == companyId && a.IsFlagged)
                .OrderByDescending(a => a.LastSeenUtc)
                .Take(take)
                .ToListAsync(ct);
        }
    }
}
