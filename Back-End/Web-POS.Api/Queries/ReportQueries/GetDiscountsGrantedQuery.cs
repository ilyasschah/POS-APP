using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetDiscountsGrantedQuery : IRequest<List<DiscountsGrantedDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
    }

    public class GetDiscountsGrantedQueryHandler
        : IRequestHandler<GetDiscountsGrantedQuery, List<DiscountsGrantedDto>>
    {
        private readonly AppDbContext _db;

        public GetDiscountsGrantedQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<DiscountsGrantedDto>> Handle(
            GetDiscountsGrantedQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.DiscountsGrantedRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            return await query
                .OrderBy(r => r.CustomerName)
                .ThenBy(r => r.Date)
                .Select(r => new DiscountsGrantedDto
                {
                    CustomerName        = r.CustomerName,
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
