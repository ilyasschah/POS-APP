using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CompanyQuery;

public class GetAllCompaniesQuery : IRequest<List<CompanyDto>>
{
    public class GetAllCompaniesQueryHandler : IRequestHandler<GetAllCompaniesQuery, List<CompanyDto>>
    {
        private readonly CompanyRepository _repository;

        public GetAllCompaniesQueryHandler(CompanyRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<CompanyDto>> Handle(GetAllCompaniesQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();
            return entities.Select(MapperCompany.MapToCompanyDto).ToList();
        }
    }
}
