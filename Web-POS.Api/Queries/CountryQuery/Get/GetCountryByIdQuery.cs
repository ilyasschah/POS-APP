using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CountryQuery.Get
{
    public class GetCountryByIdQuery : IRequest<CountryDto?>
    {
        public int Id { get; }
        public int CompanyId { get; set; }

        public GetCountryByIdQuery(int id)
        {
            Id = id;
        }

        public class GetCountryByIdQueryHandler : IRequestHandler<GetCountryByIdQuery, CountryDto?>
        {
            private readonly CountryRepository _repository;

            public GetCountryByIdQueryHandler(CountryRepository repository)
            {
                _repository = repository;
            }

            public async Task<CountryDto?> Handle(GetCountryByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetCountryId_byCompanyQuery(request.Id, request.CompanyId);
                if (entity == null) return null;
                return new CountryDto { Name = entity.Name, Code = entity.Code };
            }
        }
    }
}
