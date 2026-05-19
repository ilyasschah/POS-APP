using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetProfitQuery : IRequest<List<ProfitDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
    }

    public class GetProfitQueryHandler
        : IRequestHandler<GetProfitQuery, List<ProfitDto>>
    {
        private readonly AppDbContext _db;

        public GetProfitQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<ProfitDto>> Handle(
            GetProfitQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.ProfitRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            if (request.ProductGroupId.HasValue)
                query = query.Where(r => r.ProductGroupId == request.ProductGroupId);

            var rows = await query.ToListAsync(cancellationToken);

            return rows
                .GroupBy(r => new { r.ProductId, r.ProductCode, r.ProductName })
                .Select(g => new ProfitDto
                {
                    ProductCode = g.Key.ProductCode,
                    ProductName = g.Key.ProductName,
                    Quantity    = g.Sum(r => r.Quantity),
                    Cost        = g.Sum(r => r.Cost),
                    Total       = g.Sum(r => r.Total),
                })
                .OrderBy(r => r.ProductCode)
                .ThenBy(r => r.ProductName)
                .ToList();
        }
    }
}
