using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPurchaseInvoiceListQuery : IRequest<List<PurchaseInvoiceListDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? SupplierId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetPurchaseInvoiceListQueryHandler
        : IRequestHandler<GetPurchaseInvoiceListQuery, List<PurchaseInvoiceListDto>>
    {
        private readonly AppDbContext _db;

        public GetPurchaseInvoiceListQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PurchaseInvoiceListDto>> Handle(
            GetPurchaseInvoiceListQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.PurchaseInvoiceListRows
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
                .OrderBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .Select(r => new PurchaseInvoiceListDto
                {
                    Date             = r.Date,
                    DocumentNumber   = r.DocumentNumber,
                    ExternalDocument = r.ExternalDocument,
                    SupplierName     = r.SupplierName,
                    Total            = r.Total,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
