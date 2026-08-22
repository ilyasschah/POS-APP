using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetLowStockWarningQuery : IRequest<List<LowStockWarningDto>>
    {
        public int  CompanyId  { get; set; }
        public int? SupplierId { get; set; }
        public int? ProductId  { get; set; }
    }

    public class GetLowStockWarningQueryHandler
        : IRequestHandler<GetLowStockWarningQuery, List<LowStockWarningDto>>
    {
        private readonly AppDbContext _db;

        public GetLowStockWarningQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<LowStockWarningDto>> Handle(
            GetLowStockWarningQuery request,
            CancellationToken cancellationToken)
        {
            // Fetch all enabled stock control entries for this company
            var controls = await _db.StockControls
                .Where(sc => sc.CompanyId == request.CompanyId
                          && sc.IsLowStockWarningEnabled
                          && (!request.SupplierId.HasValue || sc.CustomerId == request.SupplierId)
                          && (!request.ProductId.HasValue  || sc.ProductId  == request.ProductId))
                .Select(sc => new
                {
                    sc.ProductId,
                    SupplierName            = sc.CustomerId == null ? "N/A" : (sc.Customer!.Name ?? "N/A"),
                    SupplierSortKey         = sc.CustomerId == null ? 0 : 1,
                    SupplierAlpha           = sc.Customer == null ? "" : (sc.Customer.Name ?? ""),
                    ProductName             = sc.Product!.Name ?? "",
                    sc.LowStockWarningQuantity,
                    sc.PreferredQuantity,
                    UOM = sc.Product.MeasurementUnit ?? "",
                })
                .ToListAsync(cancellationToken);

            if (controls.Count == 0) return [];

            // Total stock per product across all warehouses
            var productIds = controls.Select(c => c.ProductId).Distinct().ToList();
            var stockMap = await _db.Stocks
                .Where(s => s.CompanyId == request.CompanyId && productIds.Contains(s.ProductId))
                .GroupBy(s => s.ProductId)
                .Select(g => new { ProductId = g.Key, Total = g.Sum(s => s.Quantity) })
                .ToDictionaryAsync(x => x.ProductId, x => x.Total, cancellationToken);

            return controls
                .Select(c => new LowStockWarningDto
                {
                    SupplierName            = c.SupplierName,
                    ProductName             = c.ProductName,
                    CurrentStock            = stockMap.GetValueOrDefault(c.ProductId, 0),
                    LowStockWarningQuantity = c.LowStockWarningQuantity,
                    OrderQuantity           = c.PreferredQuantity,
                    UOM                     = c.UOM,
                })
                .Where(r => r.CurrentStock < r.LowStockWarningQuantity)
                .OrderBy(r => r.SupplierName == "N/A" ? 0 : 1)
                .ThenBy(r => r.SupplierName)
                .ThenBy(r => r.ProductName)
                .ToList();
        }
    }
}
