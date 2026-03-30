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
                    decimal totalSales = shiftDocuments.Sum(d => d.Total);
                    decimal totalReturns = 0;
                    decimal discountsGranted = shiftDocuments.Sum(d => d.Discount);
                    decimal taxableTotal = shiftDocuments.Sum(d => d.Total);
                    decimal totalTax = 0;

                    decimal grandTotal = unreportedPayments.Sum(p => p.Amount);

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
                        grandTotal: grandTotal
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