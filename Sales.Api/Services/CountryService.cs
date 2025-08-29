using Sales.Api.Domain;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class CountryService
    {
        public CountryRepository _countryRepository;
        public CountryService(CountryRepository countryRepository)
        {
            _countryRepository = countryRepository;
        }
        public async Task<bool> Create(string name, string code)
        {
            var cexists = _countryRepository.Exists(name);
            if (cexists == true)
                throw new ArgumentException("Country already exists.", nameof(name));
            var newcurreency = Country.Create(name, code);
            await _countryRepository.Add(newcurreency);
            return true;
        }
    }
}
