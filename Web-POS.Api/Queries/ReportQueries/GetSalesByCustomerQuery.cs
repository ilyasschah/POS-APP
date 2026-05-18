using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByCustomerQuery : IRequest<List<SalesByCustomerDto>>
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

    public class GetSalesByCustomerQueryHandler
        : IRequestHandler<GetSalesByCustomerQuery, List<SalesByCustomerDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByCustomerQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByCustomerDto>> Handle(
            GetSalesByCustomerQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByProductRows
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

            // Aggregate by customer
            var grouped = await query
                .GroupBy(r => r.CustomerId)
                .Select(g => new
                {
                    CustomerId     = g.Key,
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    Total          = g.Sum(r => r.Total),
                })
                .ToListAsync(cancellationToken);

            // Resolve customer names — filter by companyId to respect multi-tenancy
            var customerIds = grouped
                .Where(g => g.CustomerId.HasValue)
                .Select(g => g.CustomerId!.Value)
                .Distinct()
                .ToList();

            var customerNames = await _db.Customers
                .Where(c => c.CompanyId == request.CompanyId
                         && customerIds.Contains(c.Id))
                .Select(c => new { c.Id, c.Name })
                .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);

            return grouped
                .Select(g => new SalesByCustomerDto
                {
                    Customer = g.CustomerId.HasValue
                               && customerNames.TryGetValue(g.CustomerId.Value, out var name)
                               && name != null
                        ? name
                        : "Unknown",
                    TotalBeforeTax = g.TotalBeforeTax,
                    Total          = g.Total,
                })
                .OrderBy(r => r.Customer)
                .ToList();
        }
    }
}
