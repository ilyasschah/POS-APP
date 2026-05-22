using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPurchaseDiscountsQuery : IRequest<List<PurchaseDiscountsDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId { get; set; }
    }

    public class GetPurchaseDiscountsQueryHandler
        : IRequestHandler<GetPurchaseDiscountsQuery, List<PurchaseDiscountsDto>>
    {
        private readonly AppDbContext _db;

        public GetPurchaseDiscountsQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PurchaseDiscountsDto>> Handle(
            GetPurchaseDiscountsQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.PurchaseDiscountsRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.SupplierId.HasValue)
                query = query.Where(r => r.CustomerId == request.SupplierId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            return await query
                .OrderBy(r => r.SupplierName)
                .ThenBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .Select(r => new PurchaseDiscountsDto
                {
                    SupplierName        = r.SupplierName,
                    DocumentNumber      = r.DocumentNumber,
                    Date                = r.Date,
                    UserName            = r.UserName,
                    TotalBeforeDiscount = r.TotalBeforeDiscount,
                    TotalAfterDiscount  = r.TotalAfterDiscount,
                    DiscountGranted     = r.DiscountGranted,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
