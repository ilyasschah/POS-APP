using MediatR;
using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;

namespace Documents.Api.Queries.ZReportQuery
{
    public class GetAllZReportsQuery : IRequest<List<ZReportDto>>
    {
    }
    public class GetAllZReportsQueryHandler : IRequestHandler<GetAllZReportsQuery, List<ZReportDto>>
    {
        private readonly ZReportRepository _ZReportRepository;

        public GetAllZReportsQueryHandler(ZReportRepository inventoryRepository)
        {
            _ZReportRepository = inventoryRepository;
        }
        public async Task<List<ZReportDto>> Handle(GetAllZReportsQuery request, CancellationToken cancellationToken)
        {
            var ZReportEntities = await _ZReportRepository.GetAllZReportAsync();
            return ZReportEntities.Select(MapperZReport.MapToZReport).ToList();
        }
    }
}