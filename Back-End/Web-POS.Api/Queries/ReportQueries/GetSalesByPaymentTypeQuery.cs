using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByPaymentTypeQuery : IRequest<List<SalesByPaymentTypeDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetSalesByPaymentTypeQueryHandler
        : IRequestHandler<GetSalesByPaymentTypeQuery, List<SalesByPaymentTypeDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByPaymentTypeQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByPaymentTypeDto>> Handle(
            GetSalesByPaymentTypeQuery request,
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

            return await query
                .GroupBy(r => new { r.Date, r.PaymentTypeName })
                .Select(g => new SalesByPaymentTypeDto
                {
                    Date            = g.Key.Date,
                    PaymentTypeName = g.Key.PaymentTypeName,
                    Amount          = g.Sum(r => r.Amount),
                })
                .OrderBy(r => r.Date)
                .ThenBy(r => r.PaymentTypeName)
                .ToListAsync(cancellationToken);
        }
    }
}
