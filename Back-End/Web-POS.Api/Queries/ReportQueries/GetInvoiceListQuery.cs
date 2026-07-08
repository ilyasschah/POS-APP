using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetInvoiceListQuery : IRequest<List<InvoiceListDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetInvoiceListQueryHandler
        : IRequestHandler<GetInvoiceListQuery, List<InvoiceListDto>>
    {
        private readonly AppDbContext _db;

        public GetInvoiceListQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<InvoiceListDto>> Handle(
            GetInvoiceListQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.InvoiceListRows
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
                .OrderBy(r => r.Date)
                .ThenBy(r => r.DocumentNumber)
                .Select(r => new InvoiceListDto
                {
                    Date              = r.Date,
                    DocumentNumber    = r.DocumentNumber,
                    CustomerName      = r.CustomerName,
                    PaymentMethodName = r.PaymentMethodName,
                    Total             = r.Total,
                })
                .ToListAsync(cancellationToken);
        }
    }
}
