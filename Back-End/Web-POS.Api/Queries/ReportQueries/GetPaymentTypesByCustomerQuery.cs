using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPaymentTypesByCustomerQuery : IRequest<List<PaymentTypesByCustomerDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetPaymentTypesByCustomerQueryHandler
        : IRequestHandler<GetPaymentTypesByCustomerQuery, List<PaymentTypesByCustomerDto>>
    {
        private readonly AppDbContext _db;

        public GetPaymentTypesByCustomerQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PaymentTypesByCustomerDto>> Handle(
            GetPaymentTypesByCustomerQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByPaymentTypeRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            var grouped = await query
                .GroupBy(r => new { r.CustomerId, r.PaymentTypeName })
                .Select(g => new
                {
                    CustomerId      = g.Key.CustomerId,
                    PaymentTypeName = g.Key.PaymentTypeName,
                    Amount          = g.Sum(r => r.Amount),
                })
                .ToListAsync(cancellationToken);

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
                .Select(g =>
                {
                    var displayName = "Unknown";
                    if (g.CustomerId.HasValue
                        && customerNames.TryGetValue(g.CustomerId.Value, out var name)
                        && name != null)
                        displayName = name;

                    return new PaymentTypesByCustomerDto
                    {
                        CustomerName    = displayName,
                        PaymentTypeName = g.PaymentTypeName,
                        Amount          = g.Amount,
                    };
                })
                .OrderBy(r => r.CustomerName)
                .ThenBy(r => r.PaymentTypeName)
                .ToList();
        }
    }
}
