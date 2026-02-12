using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using Products.Api.Domain;
namespace Products.Api.Queries.CountryQuery.Get
{
    public class GetAllCountriesQuery : IRequest<List<CountryDto>>
    {
        public class GetAllCountriesQueryQueryHandler : IRequestHandler<GetAllCountriesQuery, List<CountryDto>>
        {
            private readonly CountryRepository _countryRepository;
            public GetAllCountriesQueryQueryHandler(CountryRepository countryRepository)
            {
                _countryRepository = countryRepository;
            }
            public async Task<List<CountryDto>> Handle(GetAllCountriesQuery request, CancellationToken cancellationToken)
            {
                var barcode = await _countryRepository.GetAllCountries();
                return barcode.Select(MapperCountry.MapToCountry).ToList();
            }
        }
    }
}
