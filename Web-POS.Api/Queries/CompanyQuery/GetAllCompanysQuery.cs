using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.CompanyQuery;

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
