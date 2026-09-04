using Api.DataBase;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    /// <summary>
    /// What a reset is allowed to clear. Deliberately coarse: every option is
    /// closed under its foreign-key dependencies (see <see cref="TablesFor"/>),
    /// because a caller cannot be trusted to work that out and a half-deleted
    /// graph is worse than no reset at all.
    /// </summary>
    public sealed class ResetCompanyDataOptions
    {
        public bool Products { get; init; }
        public bool Customers { get; init; }
        public bool Documents { get; init; }

        /// <summary>Wipes every company-scoped table except the survivors in
        /// <see cref="CompanyDataResetService.NeverReset"/>.</summary>
        public bool Everything { get; init; }

        public bool Any => Products || Customers || Documents || Everything;
    }

    public sealed record ResetCompanyDataResult(
        IReadOnlyList<string> TablesCleared,
        int RowsDeleted);

    /// <summary>
    /// Clears a company's transactional/catalogue data while leaving the company
    /// itself — and its ability to log in — intact.
    ///
    /// ⚠️ This is irreversible and company-wide: it runs on the shared database,
    /// so every terminal sees the effect on its next sync. The client is expected
    /// to have taken a local .sqlite backup first, but that only protects the
    /// device that ran it.
    ///
    /// Modelled on <c>CompanyService.DeleteAsync</c>, which had already solved
    /// the hard part: ~40 child tables reference Company with no cascade, so a
    /// delete in the wrong order trips the first FK. Both now delete in
    /// foreign-key dependency order (see <see cref="ForeignKeyDeleteOrder"/>)
    /// with constraint enforcement left ON.
    /// </summary>
    public class CompanyDataResetService(AppDbContext db)
    {
        private readonly AppDbContext _db = db;

        /// <summary>
        /// Company-scoped tables a reset must NEVER touch.
        ///
        /// <c>User</c> and <c>UserDevicePins</c>: deleting them would destroy the
        /// admin account that just authorised the reset, locking every device out
        /// of the company with no way back in short of the admin portal.
        /// <c>ApplicationProperty</c>: the operator's configured settings —
        /// printers, receipt layout, currency, tax defaults. Wiping data is the
        /// point; making them reconfigure two hundred settings is not.
        /// </summary>
        public static readonly string[] NeverReset =
        [
            "User", "UserDevicePins", "ApplicationProperty",
        ];

        // ── Dependency-closed table groups ────────────────────────────────────
        //
        // Order within a group is irrelevant HERE — ForeignKeyDeleteOrder sorts
        // whatever is selected before anything is deleted. MEMBERSHIP is what
        // matters: each group must contain everything that references it, or the
        // DELETE of a parent throws on rows outside the group that still point
        // at it. That now fails on the offending statement, inside the
        // transaction, instead of at the end on a constraint re-enable.

        /// Sales history and live orders — plus everything that hangs off a POS
        /// SESSION, because the session itself goes with them (see the filtered
        /// Shift delete in <see cref="ResetAsync"/>). ZReportPaymentSummary has
        /// no CompanyId of its own and is handled separately, by ZReportId.
        private static readonly string[] DocumentTables =
        [
            "DiscountLine", "Payment",
            "DocumentItemTax", "DocumentItemModifier", "DocumentItemExpirationDate",
            "DocumentItem", "Document",
            "PosOrderItemTax", "PosOrderItemModifier", "PosOrderItem", "PosOrder",
            "PosVoid",
            "ZReport", "ZReportCorrection",
            // Session children. FK_PosSessionPaymentCount_Shift_SessionId,
            // FK_StartingCash_Shift_SessionId and FK_ZReportCorrection_Shift_SessionId
            // all point at Shift, so they have to go with the session or the
            // WITH CHECK re-enable throws on the orphans.
            "PosSessionPaymentCount", "StartingCash",
        ];

        /// The catalogue. Requires <see cref="DocumentTables"/>: DocumentItem and
        /// PosOrderItem both carry a FK to Product, so the sales rows have to go
        /// with it. PosVoid does too, and is already above.
        private static readonly string[] ProductTables =
        [
            "Barcode", "ProductTax", "Stock", "StockControl",
            "PromotionItem", "Promotion", "Product", "ProductGroup",
        ];

        /// Requires <see cref="DocumentTables"/> as well: Document and PosOrder
        /// both reference Customer. StockControl does too, which is why it also
        /// appears here — a customers-only reset still has to clear it.
        private static readonly string[] CustomerTables =
        [
            "CustomerDiscount", "LoyaltyCard", "StockControl", "Customer",
        ];

        /// <summary>
        /// Resolves the concrete table list for [options], applying the implied
        /// dependencies. Returns distinct names; the caller does not need to
        /// de-duplicate (StockControl legitimately appears in two groups).
        /// </summary>
        public async Task<List<string>> TablesFor(ResetCompanyDataOptions options)
        {
            if (options.Everything)
            {
                var all = await _db.Database
                    .SqlQueryRaw<string>(@"
                        SELECT t.name AS Value
                        FROM sys.tables t
                        WHERE EXISTS (SELECT 1 FROM sys.columns c
                                      WHERE c.object_id = t.object_id AND c.name = 'CompanyId')
                          AND t.name <> 'Company';")
                    .ToListAsync();
                return all.Where(t => !NeverReset.Contains(t)).ToList();
            }

            var tables = new List<string>();
            // Products and Customers both DRAG documents in — see the group
            // comments. Silently doing so server-side would be a nasty surprise,
            // so the UI states it on the checkbox; this is the enforcement.
            if (options.Documents || options.Products || options.Customers)
                tables.AddRange(DocumentTables);
            if (options.Products) tables.AddRange(ProductTables);
            if (options.Customers) tables.AddRange(CustomerTables);

            return tables.Distinct().ToList();
        }

        public async Task<ResetCompanyDataResult> ResetAsync(
            int companyId, ResetCompanyDataOptions options)
        {
            if (companyId <= 0)
                throw new InvalidOperationException("A valid company is required.");
            if (!options.Any)
                throw new InvalidOperationException("Select at least one thing to reset.");

            var tables = await TablesFor(options);
            if (tables.Count == 0)
                throw new InvalidOperationException("Nothing to reset.");

            // Never let a caller (or a future edit to the group lists) delete a
            // survivor. Belt and braces on top of the filter in TablesFor.
            tables = tables.Where(t => !NeverReset.Contains(t)).ToList();

            var rows = 0;
            var strategy = _db.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync();

                // ZReportPaymentSummary has no CompanyId, so it is never in
                // [tables] and never in the ordered sweep. It hangs off BOTH
                // ZReport and PaymentType, so it has to go before either of them
                // — PaymentType is company-scoped and so is in scope on the
                // Everything branch. Filtering on ZReportId alone would leave a
                // row that then blocks the PaymentType delete.
                if (tables.Contains("ZReport") || tables.Contains("PaymentType"))
                {
                    rows += await _db.Database.ExecuteSqlRawAsync(
                        "DELETE FROM dbo.ZReportPaymentSummary " +
                        "WHERE ZReportId IN (SELECT Id FROM dbo.ZReport WHERE CompanyId = @cid) " +
                        "   OR PaymentTypeId IN (SELECT Id FROM dbo.PaymentType WHERE CompanyId = @cid);",
                        new SqlParameter("@cid", companyId));
                }

                // A Booking is a future reservation, not a sale — it outlives the
                // order it happened to open. Detach it rather than delete it, or
                // clearing sales history would silently cancel the diary.
                if (tables.Contains("PosOrder"))
                {
                    await _db.Database.ExecuteSqlRawAsync(
                        "UPDATE dbo.Booking SET PosOrderId = NULL WHERE CompanyId = @cid;",
                        new SqlParameter("@cid", companyId));
                }

                // Children before parents, so every DELETE below runs with FK
                // enforcement still ON. Ordering the SUBSET being reset is
                // enough — edges to tables outside it are ignored, because a
                // group is already closed under its dependencies (see the group
                // comments and CompanyDataResetServiceTests).
                var ordered = await ForeignKeyDeleteOrder.ResolveAsync(_db.Database, tables);

                foreach (var table in ordered)
                {
                    // A table name cannot be a query parameter, so it is
                    // interpolated — and therefore validated first. Every name
                    // here already comes from a hardcoded array or from
                    // sys.tables, never from the request. The company id stays a
                    // real parameter.
                    ForeignKeyDeleteOrder.AssertSafeIdentifier(table);
#pragma warning disable EF1002 // identifier validated by AssertSafeIdentifier
                    rows += await _db.Database.ExecuteSqlRawAsync(
                        $"DELETE FROM dbo.[{table}] WHERE CompanyId = @cid;",
                        new SqlParameter("@cid", companyId));
#pragma warning restore EF1002
                }

                // ── POS SESSIONS ──────────────────────────────────────────────
                // A session is Documents' money — same register, same day — so
                // clearing sales has to take it too. Left behind, a till whose
                // history has just been wiped reopens still believing it has
                // one, and the next session numbers itself after sales that no
                // longer exist.
                //
                // 🚨 Filtered, NOT a member of DocumentTables: ATTENDANCE shifts
                // share this table (PosDeviceId NULL) and are payroll records,
                // not sales. Wiping the day's takings must never erase who
                // worked it. `PosDeviceId IS NOT NULL` is the same discriminator
                // the domain model uses.
                //
                // Safe to run after the loop with constraints on: everything
                // that references Shift (Document, Payment, PosOrder,
                // PosSessionPaymentCount, StartingCash, ZReport,
                // ZReportCorrection) is in DocumentTables and has just gone.
                //
                // Skipped when "Shift" is already in [tables] — that is the
                // Everything branch, which deletes both shapes outright, and
                // deleting twice would double-count the reported row total.
                if (!tables.Contains("Shift")
                    && (options.Documents || options.Products || options.Customers))
                {
                    rows += await _db.Database.ExecuteSqlRawAsync(
                        "DELETE FROM dbo.Shift " +
                        "WHERE CompanyId = @cid AND PosDeviceId IS NOT NULL;",
                        new SqlParameter("@cid", companyId));
                    tables.Add("Shift");
                }

                await tx.CommitAsync();
            });

            return new ResetCompanyDataResult(tables, rows);
        }

    }
}
