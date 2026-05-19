using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetUnpaidSalesQuery : IRequest<List<UnpaidSalesDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetUnpaidSalesQueryHandler
        : IRequestHandler<GetUnpaidSalesQuery, List<UnpaidSalesDto>>
    {
        private readonly AppDbContext _db;

        public GetUnpaidSalesQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<UnpaidSalesDto>> Handle(
            GetUnpaidSalesQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.UnpaidSalesRows
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
                .OrderBy(r => r.CustomerName)
                .ThenBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .Select(r => new UnpaidSalesDto
                {
                    DocumentNumber = r.DocumentNumber,
                    Date           = r.Date,
                    DueDate        = r.DueDate,
                    CustomerName   = r.CustomerName,
                    DocumentTotal  = r.DocumentTotal,
                    TotalPaid      = r.TotalPaid,
                    TotalUnpaid    = r.TotalUnpaid,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
