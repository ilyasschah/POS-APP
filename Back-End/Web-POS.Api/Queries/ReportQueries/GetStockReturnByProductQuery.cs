using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetStockReturnByProductQuery : IRequest<List<StockReturnByProductDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
    }

    public class GetStockReturnByProductQueryHandler
        : IRequestHandler<GetStockReturnByProductQuery, List<StockReturnByProductDto>>
    {
        private readonly AppDbContext _db;

        public GetStockReturnByProductQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<StockReturnByProductDto>> Handle(
            GetStockReturnByProductQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.StockReturnByProductRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            if (request.ProductGroupId.HasValue)
                query = query.Where(r => r.ProductGroupId == request.ProductGroupId);

            return await query
                .GroupBy(r => new { r.Date, r.ProductId, r.ProductCode, r.ProductName, r.UOM })
                .Select(g => new StockReturnByProductDto
                {
                    Date           = g.Key.Date,
                    Code           = g.Key.ProductCode,
                    Product        = g.Key.ProductName,
                    Quantity       = g.Sum(r => r.Quantity),
                    UOM            = g.Key.UOM,
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    Total          = g.Sum(r => r.Total),
                })
                .OrderBy(r => r.Date)
                .ThenBy(r => r.Product)
                .ToListAsync(cancellationToken);
        }
    }
}
