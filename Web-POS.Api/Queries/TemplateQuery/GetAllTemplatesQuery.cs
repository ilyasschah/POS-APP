using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.TemplateQuery
{
    public class GetAllTemplatesQuery : IRequest<List<TemplateDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllTemplatesQueryHandler
            : IRequestHandler<GetAllTemplatesQuery, List<TemplateDto>>
        {
            private readonly TemplateRepository _repository;

            public GetAllTemplatesQueryHandler(TemplateRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<TemplateDto>> Handle(GetAllTemplatesQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperTemplate.MapToTemplateDto).ToList();
            }
        }
    }
}
