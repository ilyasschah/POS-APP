using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.DocumentQuery
{
    public class GetUnpaidByCustomerQuery : IRequest<List<UnpaidDocumentDto>>
    {
        public int CompanyId  { get; set; }
        public int CustomerId { get; set; }

        public class Handler : IRequestHandler<GetUnpaidByCustomerQuery, List<UnpaidDocumentDto>>
        {
            private readonly AppDbContext _db;

            public Handler(AppDbContext db) => _db = db;

            public async Task<List<UnpaidDocumentDto>> Handle(
                GetUnpaidByCustomerQuery request, CancellationToken cancellationToken)
            {
                // PaidStatus 0 = Unpaid, 2 = Partial. Exclude 1 (fully paid).
                var docs = await _db.Documents
                    .AsNoTracking()
                    .Where(d => d.CompanyId  == request.CompanyId
                             && d.CustomerId == request.CustomerId
                             && d.PaidStatus != 1)
                    .Include(d => d.User)
                    .Include(d => d.DocumentType)
                    .OrderBy(d => d.Date)
                    .ToListAsync(cancellationToken);

                if (docs.Count == 0) return [];

                var docIds = docs.Select(d => d.Id).ToList();

                // Batch-load payment totals per document
                var paidByDoc = await _db.Payments
                    .AsNoTracking()
                    .Where(p => docIds.Contains(p.DocumentId) && p.CompanyId == request.CompanyId)
                    .GroupBy(p => p.DocumentId)
                    .Select(g => new { DocumentId = g.Key, TotalPaid = g.Sum(p => p.Amount) })
                    .ToDictionaryAsync(x => x.DocumentId, x => x.TotalPaid, cancellationToken);

                return docs.Select(d =>
                {
                    var totalPaid = paidByDoc.GetValueOrDefault(d.Id, 0m);
                    var balance   = d.Total - totalPaid;
                    return new UnpaidDocumentDto
                    {
                        Id               = d.Id,
                        Number           = d.Number,
                        DocumentTypeName = d.DocumentType?.Name,
                        Date             = d.Date,
                        UserName         = d.User?.Username,
                        Total            = d.Total,
                        Balance          = balance > 0m ? balance : 0m,
                        DateCreated      = d.DateCreated,
                        InternalNote     = d.InternalNote,
                        Note             = d.Note,
                    };
                }).ToList();
            }
        }
    }
}
