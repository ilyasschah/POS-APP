using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByTaxQuery : IRequest<List<SalesByTaxDto>>
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

    public class GetSalesByTaxQueryHandler
        : IRequestHandler<GetSalesByTaxQuery, List<SalesByTaxDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByTaxQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByTaxDto>> Handle(
            GetSalesByTaxQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByTaxRows
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

            return await query
                .GroupBy(r => new { r.TaxId, r.TaxName })
                .Select(g => new SalesByTaxDto
                {
                    TaxName        = g.Key.TaxName,
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    TaxAmount      = g.Sum(r => r.TaxAmount),
                    Total          = g.Sum(r => r.Total),
                })
                .OrderBy(r => r.TaxName)
                .ToListAsync(cancellationToken);
        }
    }
}
