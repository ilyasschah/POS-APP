using Api.Constants;
using Api.DataBase;
using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    public class ZReportService
    {
        private readonly AppDbContext _db;
        private readonly ZReportRepository _zReportRepo;

        public ZReportService(AppDbContext db, ZReportRepository zReportRepo)
        {
            _db = db;
            _zReportRepo = zReportRepo;
        }

        /// <summary>
        /// Generates the report for ONE SESSION — the boundary is
        /// <c>SessionId</c>, never a document-id range.
        ///
        /// 🚨 What this replaces and why. The legacy path bounded a period as
        /// `Id >= from && Id <= to`, filtered by company only. With two
        /// registers trading, device B's documents fall inside device A's range
        /// and are swept into A's report, and whoever takes the second report
        /// gets a range already consumed. Cash movements had the same flaw
        /// (`ZReportNumber == null`, company-wide). Selecting by session makes
        /// contamination structurally impossible rather than unlikely.
        /// </summary>
        public async Task<ZReportDto> GenerateForSessionAsync(
            int companyId, int userId, int sessionId)
        {
            var session = await _db.Shifts
                .FirstOrDefaultAsync(s => s.Id == sessionId && s.CompanyId == companyId)
                ?? throw new InvalidOperationException($"Session {sessionId} was not found.");

            var strategy = _db.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();
                try
                {
                    var documents = await _db.Documents
                        .Where(d => d.CompanyId == companyId && d.SessionId == sessionId)
                        .ToListAsync();

                    var payments = await _db.Payments
                        .Include(p => p.PaymentType)
                        .Where(p => p.CompanyId == companyId && p.SessionId == sessionId)
                        .ToListAsync();

                    var movements = await _db.StartingCashes
                        .Where(sc => sc.CompanyId == companyId && sc.SessionId == sessionId)
                        .ToListAsync();

                    // Only sales and refunds are takings — a session can also
                    // carry purchase / inventory documents, whose totals must
                    // never land on a Z-report.
                    var sales = documents
                        .Where(d => d.DocumentTypeId == DocumentTypeConstants.Sales).ToList();
                    var refunds = documents
                        .Where(d => d.DocumentTypeId == DocumentTypeConstants.Refund).ToList();

                    decimal totalSales = sales.Sum(d => d.Total);
                    decimal totalReturns = refunds.Sum(d => Math.Abs(d.Total));
                    decimal discounts = documents.Sum(d => d.Discount);
                    // Tax lives on DocumentItemTax, not on the Document — same
                    // join the legacy path uses, bounded by session instead of
                    // an id range.
                    decimal totalTax = await (
                        from t in _db.DocumentItemTaxes
                        join i in _db.DocumentItems on t.DocumentItemId equals i.Id
                        join d in _db.Documents on i.DocumentId equals d.Id
                        where d.CompanyId == companyId && d.SessionId == sessionId
                           && (d.DocumentTypeId == DocumentTypeConstants.Sales
                            || d.DocumentTypeId == DocumentTypeConstants.Refund)
                        select (decimal?)t.Amount).SumAsync() ?? 0m;

                    // Document.Total is tax-inclusive, so the taxable base is the
                    // net takings less the tax they carry — the same identity the
                    // legacy path holds: taxable + tax == sales − returns.
                    decimal taxable = totalSales - totalReturns - totalTax;
                    // Type 0 and type 1 only. Type 2 is the opening float, which
                    // the session already carries — see StartingCash.StartingCashType.
                    decimal cashIn = movements.Where(m => m.StartingCashType == 0).Sum(m => m.Amount);
                    decimal cashOut = movements.Where(m => m.StartingCashType == 1).Sum(m => m.Amount);

                    // Per-DEVICE numbering. `Number` stays a company-wide
                    // sequence for continuity, but the human-facing number is
                    // `POS1/00085` so two registers closing at the same moment
                    // cannot collide on a fiscal document.
                    var lastForDevice = await _db.ZReports
                        .Where(z => z.CompanyId == companyId && z.PosDeviceId == session.PosDeviceId)
                        .OrderByDescending(z => z.Id)
                        .FirstOrDefaultAsync();
                    int deviceSeq = 1;
                    if (lastForDevice?.DisplayNumber != null)
                    {
                        var tail = lastForDevice.DisplayNumber.Split('/').Last();
                        if (int.TryParse(tail, out var n)) deviceSeq = n + 1;
                    }

                    var device = session.PosDeviceId is null
                        ? null
                        : await _db.PosDevices.FirstOrDefaultAsync(d => d.Id == session.PosDeviceId);

                    var lastAny = await _zReportRepo.GetLastZReportAsync(companyId);
                    int number = (lastAny?.Number ?? 0) + 1;

                    var report = ZReport.Create(
                        companyId: companyId,
                        number: number,
                        fromDocumentId: documents.Count == 0 ? 0 : documents.Min(d => d.Id),
                        toDocumentId: documents.Count == 0 ? 0 : documents.Max(d => d.Id),
                        totalSales: totalSales,
                        totalReturns: totalReturns,
                        discountsGranted: discounts,
                        taxableTotal: taxable,
                        totalTax: totalTax,
                        grandTotal: totalSales - totalReturns,
                        totalCashIn: cashIn,
                        totalCashOut: cashOut,
                        sessionId: sessionId,
                        posDeviceId: session.PosDeviceId,
                        displayNumber: ZReport.FormatDisplayNumber(device?.Name, deviceSeq));

                    _db.ZReports.Add(report);
                    await _db.SaveChangesAsync();

                    // Lock the payments to the report — the EXISTING reporting
                    // binding, unchanged. SessionId is the operational link;
                    // ZReportId remains the closing lock.
                    foreach (var p in payments) p.LockToZReport(report.Id);

                    // Cash movements bind to the SESSION now. ZReportNumber is
                    // still stamped so anything reading the legacy column keeps
                    // working while it is retired.
                    foreach (var m in movements) m.ZReportNumber = report.Number;

                    await _db.SaveChangesAsync();
                    await transaction.CommitAsync();

                    return new ZReportDto
                    {
                        Id = report.Id,
                        CompanyId = companyId,
                        Number = report.Number,
                        DateCreated = report.DateCreated,
                        FromDocumentId = report.FromDocumentId,
                        ToDocumentId = report.ToDocumentId,
                        TotalSales = totalSales,
                        TotalReturns = totalReturns,
                        DiscountsGranted = discounts,
                        TaxableTotal = taxable,
                        TotalTax = totalTax,
                        GrandTotal = totalSales - totalReturns,
                        TotalCashIn = cashIn,
                        TotalCashOut = cashOut,
                    };
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            });
        }

        /// <summary>
        /// ⚠️ LEGACY, document-range bounded. Kept only for callers that predate
        /// sessions; see <see cref="GenerateForSessionAsync"/> for why the range
        /// is unsafe with more than one register.
        /// </summary>
        public async Task<ZReportDto> GenerateZReportAsync(int companyId, int userId)
        {
            var strategy = _db.Database.CreateExecutionStrategy();

            return await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();

                try
                {
                    // Determine Document Range
                    var lastReport = await _zReportRepo.GetLastZReportAsync(companyId);
                    int fromDocumentId = lastReport != null ? lastReport.ToDocumentId + 1 : 1;

                    int toDocumentId = await _db.Documents
                        .Where(d => d.CompanyId == companyId)
                        .MaxAsync(d => (int?)d.Id) ?? 0;

                    // Fetch all UNREPORTED payments
                    var unreportedPayments = await _db.Payments
                        .Include(p => p.PaymentType)
                        .Where(p => p.CompanyId == companyId && p.ZReportId == null)
                        .ToListAsync();

                    if (fromDocumentId > toDocumentId && !unreportedPayments.Any())
                    {
                        throw new InvalidOperationException("There are no new documents or payments to generate a Z-Report.");
                    }

                    // Fetch the documents for this shift
                    var shiftDocuments = await _db.Documents
                        .Where(d => d.CompanyId == companyId && d.Id >= fromDocumentId && d.Id <= toDocumentId)
                        .ToListAsync();

                    // --- 🧮 CALCULATION ENGINE ---
                    // Only sales and refunds are takings. The id range above can
                    // also span purchase / inventory documents, whose totals must
                    // never land on a Z-report.
                    var salesDocuments = shiftDocuments
                        .Where(d => d.DocumentTypeId == DocumentTypeConstants.Sales)
                        .ToList();
                    var refundDocuments = shiftDocuments
                        .Where(d => d.DocumentTypeId == DocumentTypeConstants.Refund)
                        .ToList();

                    decimal totalSales = salesDocuments.Sum(d => d.Total);
                    // A refund's Total is stored POSITIVE here (unlike the client,
                    // which keeps it negative), so summing every document into
                    // sales — as this used to — inflated takings by the refunded
                    // amount instead of reporting it as a return.
                    decimal totalReturns = Math.Abs(refundDocuments.Sum(d => d.Total));

                    // Every discount actually applied, from the normalized
                    // DiscountLine rows: Amount is the resolved currency figure and
                    // the only summable field. The previous Document.Discount sum
                    // saw only whole-order discounts and silently missed every
                    // item-level, promotion, customer-profile and loyalty discount.
                    decimal discountsGranted = await (
                        from dl in _db.DiscountLines
                        join d in _db.Documents on dl.DocumentId equals d.Id
                        where d.CompanyId == companyId
                           && d.Id >= fromDocumentId && d.Id <= toDocumentId
                           && (d.DocumentTypeId == DocumentTypeConstants.Sales
                            || d.DocumentTypeId == DocumentTypeConstants.Refund)
                        select (decimal?)dl.Amount).SumAsync() ?? 0m;

                    // Tax lives on DocumentItemTax, not on DocumentItem.
                    decimal totalTax = await (
                        from t in _db.DocumentItemTaxes
                        join i in _db.DocumentItems on t.DocumentItemId equals i.Id
                        join d in _db.Documents on i.DocumentId equals d.Id
                        where d.CompanyId == companyId
                           && d.Id >= fromDocumentId && d.Id <= toDocumentId
                           && (d.DocumentTypeId == DocumentTypeConstants.Sales
                            || d.DocumentTypeId == DocumentTypeConstants.Refund)
                        select (decimal?)t.Amount).SumAsync() ?? 0m;

                    // Document.Total is tax-inclusive, so the taxable base is the
                    // net takings less the tax they carry. Reconciles as
                    // taxableTotal + totalTax == totalSales - totalReturns.
                    decimal taxableTotal = totalSales - totalReturns - totalTax;

                    decimal grandTotal = unreportedPayments.Sum(p => p.Amount);

                    // Cash In / Cash Out from unlinked StartingCash entries
                    var unreportedCash = await _db.StartingCashes
                        .Where(sc => sc.CompanyId == companyId && sc.ZReportNumber == null)
                        .ToListAsync();

                    // Type 0 and type 1 only; type 2 (opening float) belongs to
                    // the session, not to drawer movement.
                    decimal totalCashIn  = unreportedCash.Where(sc => sc.StartingCashType == 0).Sum(sc => sc.Amount);
                    decimal totalCashOut = unreportedCash.Where(sc => sc.StartingCashType == 1).Sum(sc => sc.Amount);

                    // Generate the Z-Report Entity
                    int nextNumber = lastReport != null ? lastReport.Number + 1 : 1;

                    var zReport = ZReport.Create(
                        companyId: companyId,
                        number: nextNumber,
                        fromDocumentId: fromDocumentId > toDocumentId ? toDocumentId : fromDocumentId,
                        toDocumentId: toDocumentId,
                        totalSales: totalSales,
                        totalReturns: totalReturns,
                        discountsGranted: discountsGranted,
                        taxableTotal: taxableTotal,
                        totalTax: totalTax,
                        grandTotal: grandTotal,
                        totalCashIn: totalCashIn,
                        totalCashOut: totalCashOut
                    );

                    await _db.ZReports.AddAsync(zReport);
                    await _db.SaveChangesAsync(); 

                    var groupedPayments = unreportedPayments
                        .GroupBy(p => new { p.PaymentTypeId, PaymentTypeName = p.PaymentType!.Name })
                        .Select(g => new
                        {
                            PaymentTypeId = g.Key.PaymentTypeId,
                            TotalAmount = g.Sum(p => p.Amount)
                        }).ToList();

                    foreach (var group in groupedPayments)
                    {
                        var summary = ZReportPaymentSummary.Create(zReport.Id, group.PaymentTypeId, group.TotalAmount);
                        await _db.ZReportPaymentSummaries.AddAsync(summary);
                    }

                    foreach (var payment in unreportedPayments)
                    {
                        payment.LockToZReport(zReport.Id);
                        _db.Payments.Update(payment);
                    }

                    foreach (var sc in unreportedCash)
                        sc.ZReportNumber = nextNumber;

                    await _db.SaveChangesAsync();
                    await transaction.CommitAsync();

                    var savedZReport = await _zReportRepo.GetByIdAsync(zReport.Id, companyId);
                    return MapperZReport.MapToZReportDto(savedZReport!);
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    throw new InvalidOperationException($"Failed to generate Z-Report: {ex.Message}", ex);
                }
            });
        }
    }
}