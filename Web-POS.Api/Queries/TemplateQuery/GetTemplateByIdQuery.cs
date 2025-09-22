using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.TemplateQuery
{
    public class GetTemplateByIdQuery : IRequest<TemplateDto?>
    {
        public int Id { get; set; }

        public class GetTemplateByIdQueryHandler
            : IRequestHandler<GetTemplateByIdQuery, TemplateDto?>
        {
            private readonly TemplateRepository _repository;

            public GetTemplateByIdQueryHandler(TemplateRepository repository)
            {
                _repository = repository;
            }

            public async Task<TemplateDto?> Handle(GetTemplateByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperTemplate.MapToTemplateDto(entity);
            }
        }
    }
}
