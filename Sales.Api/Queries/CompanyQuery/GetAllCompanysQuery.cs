// FILE: Sales.Api.Queries\CompanyQuery\GetAllCompanysQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.CompanyQuery;

public class GetAllCompanysQuery : IRequest<List<CompanyDto>>
{
    public class GetAllCompanysQueryHandler : IRequestHandler<GetAllCompanysQuery, List<CompanyDto>>
    {
        private readonly CompanyRepository _repository;

        public GetAllCompanysQueryHandler(CompanyRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<CompanyDto>> Handle(GetAllCompanysQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();
            return entities.Select(MapperCompany.MapToCompanyDto).ToList();
        }
    }
}
