using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.ZReportQuery
{
    public class GetLastZReportQuery : IRequest<ZReportDto?>
    {
        public int CompanyId { get; set; }

        public GetLastZReportQuery(int companyId)
        {
            CompanyId = companyId;
        }

        public class GetLastZReportQueryHandler : IRequestHandler<GetLastZReportQuery, ZReportDto?>
        {
            private readonly ZReportRepository _repository;

            public GetLastZReportQueryHandler(ZReportRepository repository)
            {
                _repository = repository;
            }

            public async Task<ZReportDto?> Handle(GetLastZReportQuery request, CancellationToken cancellationToken)
            {
                var zReport = await _repository.GetLastZReportAsync(request.CompanyId);
                return zReport == null ? null : MapperZReport.MapToZReportDto(zReport);
            }
        }
    }
}