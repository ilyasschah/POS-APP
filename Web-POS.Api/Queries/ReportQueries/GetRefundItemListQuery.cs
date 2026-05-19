using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetRefundItemListQuery : IRequest<List<RefundItemListDto>>
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

    public class GetRefundItemListQueryHandler
        : IRequestHandler<GetRefundItemListQuery, List<RefundItemListDto>>
    {
        private readonly AppDbContext _db;

        public GetRefundItemListQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<RefundItemListDto>> Handle(
            GetRefundItemListQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.RefundItemListRows
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
                .OrderBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .ThenBy(r => r.ProductName)
                .Select(r => new RefundItemListDto
                {
                    CustomerCode   = r.CustomerCode,
                    CustomerName   = r.CustomerName,
                    DocumentNumber = r.DocumentNumber,
                    RefNumber      = r.RefNumber,
                    Date           = r.Date,
                    DateCreated    = r.DateCreated,
                    OrderNumber    = r.OrderNumber,
                    ProductCode    = r.ProductCode,
                    ProductName    = r.ProductName,
                    Quantity       = r.Quantity,
                    UOM            = r.UOM,
                    TotalBeforeTax = r.TotalBeforeTax,
                    TotalTax       = r.TotalTax,
                    Total          = r.Total,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
