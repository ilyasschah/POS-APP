using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetTransactionHistoryQuery : IRequest<List<TransactionHistoryDto>>
    {
        public int CompanyId  { get; set; }
        public int PartnerId  { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate   { get; set; }
    }

    public class GetTransactionHistoryQueryHandler
        : IRequestHandler<GetTransactionHistoryQuery, List<TransactionHistoryDto>>
    {
        private readonly AppDbContext _db;

        public GetTransactionHistoryQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<TransactionHistoryDto>> Handle(
            GetTransactionHistoryQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            // Resolve partner name
            var partnerName = await _db.Customers
                .Where(c => c.Id == request.PartnerId && c.CompanyId == request.CompanyId)
                .Select(c => c.Name)
                .FirstOrDefaultAsync(cancellationToken) ?? "";

            // Previous balance = net of all transactions before StartDate
            var prevCredits = await _db.TransactionHistoryRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.CustomerId == request.PartnerId
                         && r.Date < start)
                .SumAsync(r => r.Credit, cancellationToken);

            var prevDebits = await _db.TransactionHistoryRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.CustomerId == request.PartnerId
                         && r.Date < start)
                .SumAsync(r => r.Debit, cancellationToken);

            var prevBalance = prevCredits - prevDebits;

            // Transactions within the requested period — fetched unordered,
            // then sorted in memory so each document row is immediately followed
            // by its payment row (same RefNumber, same date).
            var rawRows = await _db.TransactionHistoryRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.CustomerId == request.PartnerId
                         && r.Date >= start
                         && r.Date <= end)
                .ToListAsync(cancellationToken);

            // Payment rows share the same RefNumber (document number) as the
            // document row they belong to. Sort: Date → RefNumber → document
            // transactions (1) before payment transactions (2).
            var rows = rawRows
                .OrderBy(r => r.Date)
                .ThenBy(r => r.RefNumber)
                .ThenBy(r => r.TransactionType == "Payment received" ||
                             r.TransactionType == "Payment to supplier" ? 2 : 1)
                .ToList();

            // Build result with running balance
            var result = new List<TransactionHistoryDto>
            {
                new TransactionHistoryDto
                {
                    Date              = null,
                    TransactionType   = "Previous balance",
                    RefNumber         = null,
                    Credit            = 0,
                    Debit             = 0,
                    Balance           = prevBalance,
                    IsPreviousBalance = true,
                    PartnerName       = partnerName,
                }
            };

            var runningBalance = prevBalance;
            foreach (var row in rows)
            {
                runningBalance += row.Credit - row.Debit;
                result.Add(new TransactionHistoryDto
                {
                    Date              = row.Date,
                    TransactionType   = row.TransactionType,
                    RefNumber         = row.RefNumber,
                    Credit            = row.Credit,
                    Debit             = row.Debit,
                    Balance           = runningBalance,
                    IsPreviousBalance = false,
                    PartnerName       = partnerName,
                });
            }

            return result;
        }
    }
}
