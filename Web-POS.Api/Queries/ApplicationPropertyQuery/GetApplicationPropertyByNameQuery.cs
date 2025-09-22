using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;

namespace Products.Api.Queries.ApplicationPropertyQuery
{
    public class GetApplicationPropertyByNameQuery : IRequest<ApplicationPropertyDto?>
    {
        public string Name { get; set; } = default!;

        public class GetApplicationPropertyByNameQueryHandler
            : IRequestHandler<GetApplicationPropertyByNameQuery, ApplicationPropertyDto?>
        {
            private readonly ApplicationPropertyRepository _repository;

            public GetApplicationPropertyByNameQueryHandler(ApplicationPropertyRepository repository)
            {
                _repository = repository;
            }

            public async Task<ApplicationPropertyDto?> Handle(GetApplicationPropertyByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperApplicationProperty.MapToApplicationPropertyDto(entity);
            }
        }
    }
}
