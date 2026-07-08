using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByTableQuery : IRequest<List<SalesByTableDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetSalesByTableQueryHandler
        : IRequestHandler<GetSalesByTableQuery, List<SalesByTableDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByTableQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByTableDto>> Handle(
            GetSalesByTableQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByTableRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            var rows = await query.ToListAsync(cancellationToken);

            return rows
                .GroupBy(r => r.OrderNumber)
                .Select(g => new SalesByTableDto
                {
                    OrderNumber  = g.Key,
                    NumberOfSales = g.Select(r => r.DocumentId).Distinct().Count(),
                    Total        = g.Sum(r => r.Amount),
                })
                .OrderBy(r => r.OrderNumber)
                .ToList();
        }
    }
}
