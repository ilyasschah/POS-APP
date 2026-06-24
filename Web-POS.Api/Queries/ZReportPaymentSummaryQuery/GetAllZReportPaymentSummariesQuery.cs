using MediatR;
using Api.Models;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ZReportPaymentSummaryQuery
{
    /// <summary>
    /// All Z-report payment summaries for a company (offline mirror pull, v39).
    /// The entity has no CompanyId of its own, so we scope through its parent
    /// Z-report.
    /// </summary>
    public class GetAllZReportPaymentSummariesQuery : IRequest<List<ZReportPaymentSummaryDto>>
    {
        public int CompanyId { get; set; }

        public GetAllZReportPaymentSummariesQuery(int companyId) => CompanyId = companyId;

        public class Handler : IRequestHandler<GetAllZReportPaymentSummariesQuery, List<ZReportPaymentSummaryDto>>
        {
            private readonly AppDbContext _db;

            public Handler(AppDbContext db) => _db = db;

            public async Task<List<ZReportPaymentSummaryDto>> Handle(
                GetAllZReportPaymentSummariesQuery request, CancellationToken cancellationToken)
            {
                return await (from s in _db.ZReportPaymentSummaries.AsNoTracking()
                              join z in _db.ZReports.AsNoTracking() on s.ZReportId equals z.Id
                              where z.CompanyId == request.CompanyId
                              select new ZReportPaymentSummaryDto
                              {
                                  Id = s.Id,
                                  ZReportId = s.ZReportId,
                                  PaymentTypeId = s.PaymentTypeId,
                                  TotalAmount = s.TotalAmount,
                              }).ToListAsync(cancellationToken);
            }
        }
    }
}
