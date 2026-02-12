using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;

namespace Products.Api.Queries.ApplicationPropertyQuery
{
    public class GetApplicationPropertyByNameQuery : IRequest<ApplicationPropertyDto?>
    {
        public string? Name { get; set; }
        public int CompanyId { get; set; }

        public GetApplicationPropertyByNameQuery(string? name, int companyId)
        {
            Name = name;
            CompanyId = companyId;
        }
    }
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
                var entity = await _repository.GetByNameAsync(request.Name, request.CompanyId);
                if (entity == null) {
                    return null;
                }
                return new ApplicationPropertyDto
                {
                    Name = entity.Name,
                    Value = entity.Value,
                    CompanyId = entity.CompanyId,
                };
            }
        }
    }
