using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CompanyQuery;

public class GetCompanyByIdQuery : IRequest<CompanyDto>
{
    public int Id { get; set; }
    public GetCompanyByIdQuery(int id)
    {
        Id = id;
    }
    public class GetCompanyByIdQueryHandler : IRequestHandler<GetCompanyByIdQuery, CompanyDto>
    {
        private readonly CompanyRepository _companyRepository;

        public GetCompanyByIdQueryHandler(CompanyRepository companyRepository)
        {
            _companyRepository = companyRepository;
        }

        public async Task<CompanyDto> Handle(GetCompanyByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _companyRepository.GetByIdAsync(request.Id);
            if (entity == null) {
                throw new KeyNotFoundException($"Company with ID {request.Id} not found.");
            }
            return MapperCompany.MapToCompanyDto(entity);
        }
    }
}
