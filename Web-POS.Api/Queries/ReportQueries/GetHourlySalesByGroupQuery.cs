using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetHourlySalesByGroupQuery : IRequest<List<HourlySalesByGroupDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? ProductGroupId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetHourlySalesByGroupQueryHandler
        : IRequestHandler<GetHourlySalesByGroupQuery, List<HourlySalesByGroupDto>>
    {
        private readonly AppDbContext _db;

        public GetHourlySalesByGroupQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<HourlySalesByGroupDto>> Handle(
            GetHourlySalesByGroupQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.HourlySalesByGroupRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.ProductGroupId.HasValue)
                query = query.Where(r => r.ProductGroupId == request.ProductGroupId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            var rows = await query.ToListAsync(cancellationToken);

            return rows
                .GroupBy(r => (r.ProductGroup, r.Hour))
                .Select(g => new HourlySalesByGroupDto
                {
                    ProductGroup = g.Key.ProductGroup,
                    Hour         = g.Key.Hour,
                    Total        = g.Sum(r => r.Amount),
                })
                .OrderBy(r => r.ProductGroup)
                .ThenBy(r => r.Hour)
                .ToList();
        }
    }
}
