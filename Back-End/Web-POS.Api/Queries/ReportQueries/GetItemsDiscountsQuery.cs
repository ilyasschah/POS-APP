using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetItemsDiscountsQuery : IRequest<List<ItemsDiscountsDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? ProductId { get; set; }
    }

    public class GetItemsDiscountsQueryHandler
        : IRequestHandler<GetItemsDiscountsQuery, List<ItemsDiscountsDto>>
    {
        private readonly AppDbContext _db;

        public GetItemsDiscountsQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<ItemsDiscountsDto>> Handle(
            GetItemsDiscountsQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.ItemsDiscountsRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            return await query
                .GroupBy(r => new { r.ProductId, r.ProductCode, r.ProductName })
                .Select(g => new ItemsDiscountsDto
                {
                    ProductCode   = g.Key.ProductCode,
                    ProductName   = g.Key.ProductName,
                    TotalDiscount = g.Sum(r => r.TotalDiscount),
                })
                .OrderBy(r => r.ProductName)
                .ToListAsync(cancellationToken);
        }
    }
}
