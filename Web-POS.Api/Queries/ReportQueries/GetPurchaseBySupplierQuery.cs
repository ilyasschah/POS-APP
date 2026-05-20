using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPurchaseBySupplierQuery : IRequest<List<PurchaseBySupplierDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
    }

    public class GetPurchaseBySupplierQueryHandler
        : IRequestHandler<GetPurchaseBySupplierQuery, List<PurchaseBySupplierDto>>
    {
        private readonly AppDbContext _db;

        public GetPurchaseBySupplierQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PurchaseBySupplierDto>> Handle(
            GetPurchaseBySupplierQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.PurchaseByProductRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.SupplierId.HasValue)
                query = query.Where(r => r.CustomerId == request.SupplierId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            if (request.ProductGroupId.HasValue)
                query = query.Where(r => r.ProductGroupId == request.ProductGroupId);

            var grouped = await query
                .GroupBy(r => r.CustomerId)
                .Select(g => new
                {
                    SupplierId     = g.Key,
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    Total          = g.Sum(r => r.Total),
                })
                .ToListAsync(cancellationToken);

            var supplierIds = grouped
                .Where(g => g.SupplierId.HasValue)
                .Select(g => g.SupplierId!.Value)
                .Distinct()
                .ToList();

            var supplierNames = await _db.Customers
                .Where(c => c.CompanyId == request.CompanyId && supplierIds.Contains(c.Id))
                .Select(c => new { c.Id, c.Name })
                .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);

            return grouped
                .Select(g => new PurchaseBySupplierDto
                {
                    Supplier = g.SupplierId.HasValue
                               && supplierNames.TryGetValue(g.SupplierId.Value, out var name)
                               && name != null
                        ? name
                        : "Unknown",
                    TotalBeforeTax = g.TotalBeforeTax,
                    Total          = g.Total,
                })
                .OrderBy(r => r.Supplier)
                .ToList();
        }
    }
}
