using MediatR;
using Api.Domain;
using Api.Repository;
using Api.Helpers;
using Api.Models;
namespace Api.Queries.CountryQuery.Get
{
    public class GetAllCountriesQuery : IRequest<List<CountryDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllCountriesQueryQueryHandler : IRequestHandler<GetAllCountriesQuery, List<CountryDto>>
        {
            private readonly CountryRepository _countryRepository;
            public GetAllCountriesQueryQueryHandler(CountryRepository countryRepository)
            {
                _countryRepository = countryRepository;
            }
            public async Task<List<CountryDto>> Handle(GetAllCountriesQuery request, CancellationToken cancellationToken)
            {
                var countries = await _countryRepository.GetAllCountries(request.CompanyId);
                return countries.Select(MapperCountry.MapToCountry).ToList();
            }
        }
    }
}
