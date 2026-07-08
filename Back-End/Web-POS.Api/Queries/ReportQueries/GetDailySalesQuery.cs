using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetDailySalesQuery : IRequest<List<DailySalesDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetDailySalesQueryHandler
        : IRequestHandler<GetDailySalesQuery, List<DailySalesDto>>
    {
        private readonly AppDbContext _db;

        public GetDailySalesQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<DailySalesDto>> Handle(
            GetDailySalesQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.DailySalesRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            return await query
                .GroupBy(r => r.Date)
                .Select(g => new DailySalesDto
                {
                    Date  = g.Key,
                    Total = g.Sum(r => r.Amount),
                })
                .OrderBy(r => r.Date)
                .ToListAsync(cancellationToken);
        }
    }
}
