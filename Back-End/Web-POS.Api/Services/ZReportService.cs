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
                        .GroupBy(p => new { p.PaymentTypeId, PaymentTypeName = p.PaymentType.Name })
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