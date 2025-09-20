using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.TemplateQuery
{
    public class GetAllTemplatesQuery : IRequest<List<TemplateDto>>
    {
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
                var list = await _repository.GetAllAsync();
                return list.Select(MapperTemplate.MapToTemplateDto).ToList();
            }
        }
    }
}
