using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.ZReportQuery
{
    public class GetAllZReportsQuery : IRequest<IEnumerable<ZReportDto>>
    {
        public int CompanyId { get; set; }

        public GetAllZReportsQuery(int companyId)
        {
            CompanyId = companyId;
        }

        public class GetAllZReportsQueryHandler : IRequestHandler<GetAllZReportsQuery, IEnumerable<ZReportDto>>
        {
            private readonly ZReportRepository _repository;

            public GetAllZReportsQueryHandler(ZReportRepository repository)
            {
                _repository = repository;
            }

            public async Task<IEnumerable<ZReportDto>> Handle(GetAllZReportsQuery request, CancellationToken cancellationToken)
            {
                var zReports = await _repository.GetAllAsync(request.CompanyId);
                return zReports.Select(MapperZReport.MapToZReportDto);
            }
        }
    }
}