using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.ZReportQueries
{
    public class GetZReportByIdQuery : IRequest<ZReportDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public GetZReportByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class GetZReportByIdQueryHandler : IRequestHandler<GetZReportByIdQuery, ZReportDto?>
        {
            private readonly ZReportRepository _repository;

            public GetZReportByIdQueryHandler(ZReportRepository repository)
            {
                _repository = repository;
            }

            public async Task<ZReportDto?> Handle(GetZReportByIdQuery request, CancellationToken cancellationToken)
            {
                var zReport = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return zReport == null ? null : MapperZReport.MapToZReportDto(zReport);
            }
        }
    }
}