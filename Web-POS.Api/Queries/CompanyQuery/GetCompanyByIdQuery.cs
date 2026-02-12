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
        private readonly CompanyRepository _repository;

        public GetCompanyByIdQueryHandler(CompanyRepository repository)
        {
            _repository = repository;
        }

        public async Task<CompanyDto> Handle(GetCompanyByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id);
            if (entity == null) {
                throw new KeyNotFoundException($"Company with ID {request.Id} not found.");
            }
            return MapperCompany.MapToCompanyDto(entity);
        }
    }
}
