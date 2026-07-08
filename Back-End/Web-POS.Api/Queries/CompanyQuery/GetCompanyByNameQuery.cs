using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.CompanyQuery;

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
