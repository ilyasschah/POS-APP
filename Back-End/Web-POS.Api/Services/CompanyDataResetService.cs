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
    /// plain ordered delete trips the first FK. Constraints are disabled for the
    /// duration and re-armed WITH CHECK afterwards.
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
        // Order within a group is irrelevant (constraints are off), but MEMBERSHIP
        // is not: the re-enable at the end is `WITH CHECK`, which re-validates
        // every row. Leave one orphan behind and that statement throws, taking
        // the whole transaction with it. So each group must contain everything
        // that references it.

        /// Sales history and live orders. ZReportPaymentSummary has no CompanyId
        /// of its own and is handled separately, by ZReportId.
        private static readonly string[] DocumentTables =
        [
            "DiscountLine", "Payment",
            "DocumentItemTax", "DocumentItemExpirationDate", "DocumentItem", "Document",
            "PosOrderItemTax", "PosOrderItem", "PosOrder", "PosVoid",
            "ZReport",
        ];

        /// The catalogue. Requires <see cref="DocumentTables"/>: DocumentItem and
        /// PosOrderItem both carry a FK to Product, so the sales rows have to go
        /// with it. PosVoid does too, and is already above.
        private static readonly string[] ProductTables =
        [
            "Barcode", "ProductTax", "ProductComment", "Stock", "StockControl",
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

                // ZReportPaymentSummary has no CompanyId; it hangs off ZReport.
                // Must go before ZReport, and only when ZReport is in scope.
                if (tables.Contains("ZReport"))
                {
                    rows += await _db.Database.ExecuteSqlRawAsync(
                        "DELETE FROM dbo.ZReportPaymentSummary WHERE ZReportId IN " +
                        "(SELECT Id FROM dbo.ZReport WHERE CompanyId = @cid);",
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

                await SetConstraintsAsync(enabled: false);
                try
                {
                    foreach (var table in tables)
                    {
                        // A table name cannot be a query parameter, so it is
                        // interpolated — and therefore validated first. Every
                        // name here already comes from a hardcoded array or from
                        // sys.tables, never from the request, but this is a
                        // DELETE loop running with FK enforcement OFF: the cost
                        // of being wrong is the whole database, so it is checked
                        // rather than reasoned about. The company id stays a
                        // real parameter.
                        AssertSafeIdentifier(table);
#pragma warning disable EF1002 // identifier validated by AssertSafeIdentifier
                        rows += await _db.Database.ExecuteSqlRawAsync(
                            $"DELETE FROM dbo.[{table}] WHERE CompanyId = @cid;",
                            new SqlParameter("@cid", companyId));
#pragma warning restore EF1002
                    }
                }
                finally
                {
                    // MUST run even if a delete throws: leaving the database with
                    // FK enforcement off is far worse than a failed reset.
                    await SetConstraintsAsync(enabled: true);
                }

                await tx.CommitAsync();
            });

            return new ResetCompanyDataResult(tables, rows);
        }

        /// <summary>
        /// Toggles FK enforcement on the company-scoped tables only. Global
        /// reference tables (Country, Currency, DocumentType, DocumentCategory)
        /// have no CompanyId and are never touched, so a reset cannot affect
        /// data shared with other tenants.
        ///
        /// Re-enabling uses <c>WITH CHECK CHECK</c>, not a bare
        /// <c>CHECK CONSTRAINT</c>: the bare form re-arms the constraint but
        /// leaves it <c>is_not_trusted</c>, because SQL Server never re-validates
        /// the existing rows. That would both hide an orphan this reset created
        /// and drop the FK out of the optimiser's join elimination.
        /// </summary>
        /// <summary>
        /// Rejects anything that is not a plain SQL identifier. Table names have
        /// to be interpolated (they cannot be parameters), so they are proven
        /// safe rather than assumed safe — see the call site.
        /// </summary>
        private static void AssertSafeIdentifier(string name)
        {
            if (!System.Text.RegularExpressions.Regex.IsMatch(
                    name, @"^[A-Za-z][A-Za-z0-9_]*$"))
            {
                throw new InvalidOperationException(
                    $"Refusing to build SQL for unsafe table name '{name}'.");
            }
        }

        private Task SetConstraintsAsync(bool enabled)
        {
            // Two fixed literals chosen by a bool — no external input reaches
            // this string.
            var clause = enabled
                ? "WITH CHECK CHECK CONSTRAINT ALL"
                : "NOCHECK CONSTRAINT ALL";

#pragma warning disable EF1002 // clause is one of two compile-time constants
            return _db.Database.ExecuteSqlRawAsync($@"
                DECLARE @sql NVARCHAR(MAX) = N'';
                SELECT @sql += 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name)
                             + ' {clause};' + CHAR(10)
                FROM sys.tables t
                WHERE EXISTS (SELECT 1 FROM sys.columns c
                              WHERE c.object_id = t.object_id AND c.name = 'CompanyId');
                EXEC sp_executesql @sql;");
#pragma warning restore EF1002
        }
    }
}
