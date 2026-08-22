using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ProductsQuery
{
    public class GetProductsForExportQuery : IRequest<List<ProductExportDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetProductsForExportQueryHandler
        : IRequestHandler<GetProductsForExportQuery, List<ProductExportDto>>
    {
        private readonly AppDbContext _db;
        public GetProductsForExportQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<ProductExportDto>> Handle(
            GetProductsForExportQuery request,
            CancellationToken ct)
        {
            var products = await _db.Products
                .Where(p => p.CompanyId == request.CompanyId)
                .Select(p => new
                {
                    p.Id, p.Name,
                    ProductGroupName = p.ProductGroup == null ? null : p.ProductGroup.Name,
                    p.Code, p.PLU, p.MeasurementUnit, p.UomId, p.IsToWeigh,
                    p.Cost, p.Markup, p.Price,
                    p.IsTaxInclusivePrice, p.IsPriceChangeAllowed,
                    p.IsUsingDefaultQuantity, p.IsService, p.IsEnabled,
                    p.Description, p.Color, p.Rank,
                    p.AgeRestriction, p.LastPurchasePrice,
                    p.DateCreated, p.DateUpdated,
                })
                .ToListAsync(ct);

            if (products.Count == 0) return [];

            var productIds = products.Select(p => p.Id).ToList();

            var barcodeMap = (await _db.Barcodes
                .Where(b => b.CompanyId == request.CompanyId && productIds.Contains(b.ProductId))
                .Select(b => new { b.ProductId, b.Value })
                .ToListAsync(ct))
                .GroupBy(b => b.ProductId)
                .ToDictionary(g => g.Key, g => g.Select(b => b.Value ?? "").ToList());

            var taxMap = (await _db.ProductsTaxes
                .Where(pt => pt.CompanyId == request.CompanyId && productIds.Contains(pt.ProductId))
                .Select(pt => new
                {
                    pt.ProductId,
                    TaxId   = pt.TaxId,
                    Name    = pt.Tax!.Name,
                    Rate    = pt.Tax.Rate,
                    Code    = pt.Tax.Code,
                    pt.Tax.IsFixed,
                    pt.Tax.IsTaxOnTotal,
                    TaxEnabled = pt.Tax.IsEnabled,
                })
                .ToListAsync(ct))
                .GroupBy(t => t.ProductId)
                .ToDictionary(g => g.Key, g => g.Select(t => new TaxExportDto
                {
                    Id = t.TaxId, Name = t.Name, Rate = t.Rate,
                    Code = t.Code, IsFixed = t.IsFixed,
                    IsTaxOnTotal = t.IsTaxOnTotal, IsEnabled = t.TaxEnabled,
                }).ToList());

            var commentMap = (await _db.ProductComments
                .Where(c => c.CompanyId == request.CompanyId && productIds.Contains(c.ProductId))
                .Select(c => new { c.ProductId, c.Comment })
                .ToListAsync(ct))
                .GroupBy(c => c.ProductId)
                .ToDictionary(g => g.Key, g => g.Select(c => c.Comment).ToList());

            var stockMap = await _db.Stocks
                .Where(s => s.CompanyId == request.CompanyId && productIds.Contains(s.ProductId))
                .GroupBy(s => s.ProductId)
                .Select(g => new { ProductId = g.Key, Total = g.Sum(s => s.Quantity) })
                .ToDictionaryAsync(x => x.ProductId, x => x.Total, ct);

            var scMap = (await _db.StockControls
                .Where(sc => sc.CompanyId == request.CompanyId && productIds.Contains(sc.ProductId))
                .Select(sc => new
                {
                    sc.ProductId,
                    SupplierName             = sc.CustomerId == null ? null : sc.Customer!.Name,
                    sc.ReorderPoint,
                    sc.PreferredQuantity,
                    sc.IsLowStockWarningEnabled,
                    sc.LowStockWarningQuantity,
                })
                .ToListAsync(ct))
                .ToDictionary(sc => sc.ProductId);

            return products
                .Select(p =>
                {
                    var sc = scMap.GetValueOrDefault(p.Id);
                    return new ProductExportDto
                    {
                        Id                       = p.Id,
                        Name                     = p.Name,
                        ProductGroupName         = p.ProductGroupName,
                        Code                     = p.Code,
                        PLU                      = p.PLU,
                        MeasurementUnit          = p.MeasurementUnit,
                        UomId                    = p.UomId,
                        IsToWeigh                = p.IsToWeigh,
                        Cost                     = p.Cost,
                        Markup                   = p.Markup,
                        Price                    = p.Price,
                        IsTaxInclusivePrice      = p.IsTaxInclusivePrice,
                        IsPriceChangeAllowed     = p.IsPriceChangeAllowed,
                        IsUsingDefaultQuantity   = p.IsUsingDefaultQuantity,
                        IsService                = p.IsService,
                        IsEnabled                = p.IsEnabled,
                        Description              = p.Description,
                        Color                    = p.Color,
                        Rank                     = p.Rank,
                        AgeRestriction           = p.AgeRestriction,
                        LastPurchasePrice        = p.LastPurchasePrice,
                        DateCreated              = p.DateCreated,
                        DateUpdated              = p.DateUpdated,
                        TotalStock               = stockMap.GetValueOrDefault(p.Id, 0),
                        SupplierName             = sc?.SupplierName,
                        ReorderPoint             = sc?.ReorderPoint             ?? 0,
                        PreferredQuantity        = sc?.PreferredQuantity        ?? 0,
                        IsLowStockWarningEnabled = sc?.IsLowStockWarningEnabled ?? false,
                        LowStockWarningQuantity  = sc?.LowStockWarningQuantity  ?? 0,
                        Barcodes                 = barcodeMap.GetValueOrDefault(p.Id, []),
                        Taxes                    = taxMap.GetValueOrDefault(p.Id, []),
                        Comments                 = commentMap.GetValueOrDefault(p.Id, []),
                    };
                })
                .OrderBy(p => p.ProductGroupName)
                .ThenBy(p => p.Name)
                .ToList();
        }
    }
}
