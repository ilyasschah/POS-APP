using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPurchaseItemsDiscountsQuery : IRequest<List<PurchaseItemsDiscountsDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId { get; set; }
        public int? ProductId { get; set; }
    }

    public class GetPurchaseItemsDiscountsQueryHandler
        : IRequestHandler<GetPurchaseItemsDiscountsQuery, List<PurchaseItemsDiscountsDto>>
    {
        private readonly AppDbContext _db;

        public GetPurchaseItemsDiscountsQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PurchaseItemsDiscountsDto>> Handle(
            GetPurchaseItemsDiscountsQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.PurchaseItemsDiscountsRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.SupplierId.HasValue)
                query = query.Where(r => r.CustomerId == request.SupplierId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            return await query
                .OrderBy(r => r.SupplierName)
                .ThenBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .ThenBy(r => r.ProductName)
                .Select(r => new PurchaseItemsDiscountsDto
                {
                    SupplierName        = r.SupplierName,
                    DocumentNumber      = r.DocumentNumber,
                    Date                = r.Date,
                    UserName            = r.UserName,
                    ProductCode         = r.ProductCode,
                    ProductName         = r.ProductName,
                    Quantity            = r.Quantity,
                    Cost                = r.Cost,
                    TotalBeforeDiscount = r.TotalBeforeDiscount,
                    TotalAfterDiscount  = r.TotalAfterDiscount,
                    DiscountValue       = r.DiscountValue,
                    DiscountType        = r.DiscountType,
                    TotalDiscount       = r.TotalDiscount,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
