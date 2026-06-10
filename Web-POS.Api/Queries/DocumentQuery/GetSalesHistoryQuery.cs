using MediatR;
using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Models;

namespace Api.Queries.DocumentQuery
{
    public class GetSalesHistoryQuery : IRequest<List<SalesHistoryDocumentDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? UserId { get; set; }
        public int? CustomerId { get; set; }
        // When true, each document also carries its line items (used by the
        // offline sync pull so the local DB can compute dashboards/reports).
        public bool IncludeItems { get; set; }

        public class Handler : IRequestHandler<GetSalesHistoryQuery, List<SalesHistoryDocumentDto>>
        {
            private readonly AppDbContext _db;

            public Handler(AppDbContext db) => _db = db;

            public async Task<List<SalesHistoryDocumentDto>> Handle(
                GetSalesHistoryQuery request, CancellationToken cancellationToken)
            {
                var startDate = request.StartDate.Date;
                var endDate   = request.EndDate.Date;

                var docsQuery = _db.Documents
                    .AsNoTracking()
                    .Where(d => d.CompanyId    == request.CompanyId
                             && d.DocumentTypeId == 2   // Sales
                             && d.Date           >= startDate
                             && d.Date           <= endDate);

                if (request.UserId.HasValue)
                    docsQuery = docsQuery.Where(d => d.UserId == request.UserId.Value);

                if (request.CustomerId.HasValue)
                    docsQuery = docsQuery.Where(d => d.CustomerId == request.CustomerId.Value);

                var docs = await docsQuery
                    .Include(d => d.User)
                    .Include(d => d.Customer)
                    .Include(d => d.Warehouse)
                    .OrderByDescending(d => d.StockDate)
                    .ToListAsync(cancellationToken);

                if (docs.Count == 0) return [];

                var docIds = docs.Select(d => d.Id).ToList();

                var payments = await _db.Payments
                    .AsNoTracking()
                    .Where(p => docIds.Contains(p.DocumentId))
                    .Include(p => p.PaymentType)
                    .ToListAsync(cancellationToken);

                var items = await _db.DocumentItems
                    .AsNoTracking()
                    .Where(di => docIds.Contains(di.DocumentId))
                    .Select(di => new
                    {
                        di.DocumentId,
                        di.ProductId,
                        di.Quantity,
                        di.Price,
                        di.Discount,
                        di.DiscountType,
                        di.PriceBeforeTax,
                        di.Total,
                    })
                    .ToListAsync(cancellationToken);

                var paymentsByDoc = payments
                    .GroupBy(p => p.DocumentId)
                    .ToDictionary(g => g.Key, g => g.ToList());

                var taxByDoc = items
                    .GroupBy(i => i.DocumentId)
                    .ToDictionary(g => g.Key, g => g.Sum(i => i.PriceBeforeTax * i.Quantity));

                var itemsByDoc = request.IncludeItems
                    ? items
                        .GroupBy(i => i.DocumentId)
                        .ToDictionary(
                            g => g.Key,
                            g => g.Select(i => new SalesHistoryItemDto
                            {
                                ProductId    = i.ProductId,
                                Quantity     = i.Quantity,
                                UnitPrice    = i.Price,
                                Discount     = i.Discount,
                                DiscountType = i.DiscountType,
                                Total        = i.Total,
                            }).ToList())
                    : new Dictionary<int, List<SalesHistoryItemDto>>();

                return docs.Select(d =>
                {
                    var docPays        = paymentsByDoc.GetValueOrDefault(d.Id) ?? [];
                    var totalBeforeTax = taxByDoc.GetValueOrDefault(d.Id);
                    return new SalesHistoryDocumentDto
                    {
                        Id                       = d.Id,
                        Number                   = d.Number,
                        UserName                 = d.User?.Username ?? "N/A",
                        CustomerId               = d.CustomerId,
                        CustomerName             = d.Customer?.Name,
                        WarehouseName            = d.Warehouse?.Name,
                        OrderNumber              = d.OrderNumber,
                        ReferenceDocumentNumber  = d.ReferenceDocumentNumber,
                        Date                     = d.Date,
                        StockDate                = d.StockDate,
                        DateCreated              = d.DateCreated,
                        Total                    = d.Total,
                        TotalBeforeTax           = totalBeforeTax,
                        TaxTotal                 = d.Total - totalBeforeTax,
                        Discount                 = d.Discount,
                        PaidStatus               = d.PaidStatus,
                        PaymentSummary           = docPays.Count > 0
                            ? string.Join(" / ", docPays
                                .Select(p => p.PaymentType?.Name)
                                .Where(n => n != null)
                                .Distinct())
                            : "N/A",
                        Items = itemsByDoc.GetValueOrDefault(d.Id) ?? [],
                    };
                }).ToList();
            }
        }
    }
}
