using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetReorderProductListQuery : IRequest<List<ReorderProductListDto>>
    {
        public int  CompanyId  { get; set; }
        public int? SupplierId { get; set; }
        public int? ProductId  { get; set; }
    }

    public class GetReorderProductListQueryHandler
        : IRequestHandler<GetReorderProductListQuery, List<ReorderProductListDto>>
    {
        private readonly AppDbContext _db;

        public GetReorderProductListQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<ReorderProductListDto>> Handle(
            GetReorderProductListQuery request,
            CancellationToken cancellationToken)
        {
            return await _db.StockControls
                .Where(sc => sc.CompanyId == request.CompanyId
                          && (!request.SupplierId.HasValue || sc.CustomerId == request.SupplierId)
                          && (!request.ProductId.HasValue  || sc.ProductId  == request.ProductId))
                // Nulls (N/A) first, then alphabetical by supplier, then by product
                .OrderBy(sc => sc.CustomerId == null ? 0 : 1)
                .ThenBy(sc => sc.Customer == null ? "" : sc.Customer.Name)
                .ThenBy(sc => sc.Product.Name)
                .Select(sc => new ReorderProductListDto
                {
                    SupplierName  = sc.CustomerId == null ? "N/A" : (sc.Customer.Name ?? "N/A"),
                    ProductName   = sc.Product.Name ?? "",
                    OrderQuantity = sc.PreferredQuantity,
                    UOM           = sc.Product.MeasurementUnit ?? "",
                })
                .ToListAsync(cancellationToken);
        }
    }
}
