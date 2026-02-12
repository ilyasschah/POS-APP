using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CompanyQuery;

public class GetCompanyByNameQuery : IRequest<CompanyDto>
{
    public string Name { get; set; }
    public GetCompanyByNameQuery(string name)
    {
        Name = name;
    }
    public class GetCompanyByNameQueryHandler : IRequestHandler<GetCompanyByNameQuery, CompanyDto>
    {
        private readonly CompanyRepository _repository;

        public GetCompanyByNameQueryHandler(CompanyRepository repository)
        {
            _repository = repository;
        }

        public async Task<CompanyDto> Handle(GetCompanyByNameQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByNameAsync(request.Name);
            if (entity == null)
            {
                throw new KeyNotFoundException($"Company with Name {request.Name} not found.");
            }
            return MapperCompany.MapToCompanyDto(entity);
        }
    }
}
