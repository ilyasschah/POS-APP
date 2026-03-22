using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.TemplateQuery
{
    public class GetTemplateByNameQuery : IRequest<TemplateDto?>
    {
        public string Name { get; set; } = default!;

        public class GetTemplateByNameQueryHandler
            : IRequestHandler<GetTemplateByNameQuery, TemplateDto?>
        {
            private readonly TemplateRepository _repository;

            public GetTemplateByNameQueryHandler(TemplateRepository repository)
            {
                _repository = repository;
            }

            public async Task<TemplateDto?> Handle(GetTemplateByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperTemplate.MapToTemplateDto(entity);
            }
        }
    }
}
