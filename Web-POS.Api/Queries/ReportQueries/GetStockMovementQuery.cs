using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetStockMovementQuery : IRequest<List<StockMovementDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? UserId { get; set; }
        public int? ProductId { get; set; }
    }

    public class GetStockMovementQueryHandler
        : IRequestHandler<GetStockMovementQuery, List<StockMovementDto>>
    {
        private readonly AppDbContext _db;

        public GetStockMovementQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<StockMovementDto>> Handle(
            GetStockMovementQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.StockMovementRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            // Sum quantity per product, then compute average in memory
            var perProduct = await query
                .GroupBy(r => new { r.ProductId, r.ProductCode, r.ProductName })
                .Select(g => new StockMovementDto
                {
                    ProductCode = g.Key.ProductCode,
                    ProductName = g.Key.ProductName,
                    NumSales    = g.Sum(r => r.Quantity),
                })
                .ToListAsync(cancellationToken);

            if (perProduct.Count == 0) return perProduct;

            var total   = perProduct.Sum(p => p.NumSales);
            var average = total / perProduct.Count;

            // Sort: fast moving (>= average) descending, slow moving (< average) descending
            return perProduct
                .OrderByDescending(p => p.NumSales >= average)
                .ThenByDescending(p => p.NumSales)
                .ToList();
        }
    }
}
