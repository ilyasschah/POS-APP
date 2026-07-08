using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetUnpaidPurchaseQuery : IRequest<List<UnpaidPurchaseDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetUnpaidPurchaseQueryHandler
        : IRequestHandler<GetUnpaidPurchaseQuery, List<UnpaidPurchaseDto>>
    {
        private readonly AppDbContext _db;

        public GetUnpaidPurchaseQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<UnpaidPurchaseDto>> Handle(
            GetUnpaidPurchaseQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.UnpaidPurchaseRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.SupplierId.HasValue)
                query = query.Where(r => r.CustomerId == request.SupplierId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            return await query
                .OrderBy(r => r.SupplierName)
                .ThenBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .Select(r => new UnpaidPurchaseDto
                {
                    DocumentNumber = r.DocumentNumber,
                    Date           = r.Date,
                    DueDate        = r.DueDate,
                    SupplierName   = r.SupplierName,
                    DocumentTotal  = r.DocumentTotal,
                    TotalPaid      = r.TotalPaid,
                    TotalUnpaid    = r.TotalUnpaid,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
