using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPurchaseExpirationDateQuery : IRequest<List<PurchaseExpirationDateDto>>
    {
        public int CompanyId   { get; set; }
        public DateTime StartDate  { get; set; }
        public DateTime EndDate    { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId     { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId  { get; set; }
        public int? ProductGroupId { get; set; }
    }

    public class GetPurchaseExpirationDateQueryHandler
        : IRequestHandler<GetPurchaseExpirationDateQuery, List<PurchaseExpirationDateDto>>
    {
        private readonly AppDbContext _db;

        public GetPurchaseExpirationDateQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PurchaseExpirationDateDto>> Handle(
            GetPurchaseExpirationDateQuery request,
            CancellationToken cancellationToken)
        {
            // Filter: show items whose expiration date falls within [StartDate, EndDate]
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.PurchaseExpirationDateRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.ExpirationDate >= start
                         && r.ExpirationDate <= end);

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

            return await query
                .OrderBy(r => r.ExpirationDate)
                .ThenBy(r => r.ProductName)
                .Select(r => new PurchaseExpirationDateDto
                {
                    ProductCode    = r.ProductCode,
                    ProductName    = r.ProductName,
                    Quantity       = r.Quantity,
                    UOM            = r.UOM,
                    ExpirationDate = r.ExpirationDate,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
