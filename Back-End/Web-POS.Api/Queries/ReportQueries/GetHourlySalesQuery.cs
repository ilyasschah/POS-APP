using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetHourlySalesQuery : IRequest<List<HourlySalesDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetHourlySalesQueryHandler
        : IRequestHandler<GetHourlySalesQuery, List<HourlySalesDto>>
    {
        private readonly AppDbContext _db;

        public GetHourlySalesQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<HourlySalesDto>> Handle(
            GetHourlySalesQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.HourlySalesRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            // Fetch filtered rows then group in-memory so DISTINCT count is reliable
            var rows = await query.ToListAsync(cancellationToken);

            return rows
                .GroupBy(r => r.Hour)
                .Select(g => new HourlySalesDto
                {
                    Hour       = g.Key,
                    TotalSales = g.Sum(r => r.Amount),
                    SalesCount = g.Select(r => r.DocumentId).Distinct().Count(),
                })
                .OrderBy(r => r.Hour)
                .ToList();
        }
    }
}
