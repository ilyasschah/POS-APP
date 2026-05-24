using Api.Domain;
using Api.Repository;

namespace Api.Services
{
    public class CountryService
    {
        public CountryRepository _countryRepository;
        public CountryService(CountryRepository countryRepository)
        {
            _countryRepository = countryRepository;
        }
        public async Task<bool> Create(string name, string code, int companyId)
        {
            var cexists = _countryRepository.Exists(name, companyId);
            if (cexists == true)
                throw new ArgumentException("Country already exists.", nameof(name));
            var newcountry = Country.Create(companyId, name, code);
            await _countryRepository.Add(newcountry);
            return true;
        }

        public async Task<bool> Update(int id, string newName, string? newCode, int companyId)
        {
            var entity = await _countryRepository.GetCountryId_byCompanyQuery(id, companyId);
            if (entity == null) return false;
            entity.UpdateName(newName);
            entity.Code = newCode;
            await _countryRepository.Update(entity);
            return true;
        }

        public async Task<bool> Delete(int id, int companyId)
        {
            var entity = await _countryRepository.GetCountryId_byCompanyQuery(id, companyId);
            if (entity == null) return false;
            await _countryRepository.DeleteAsync(entity);
            return true;
        }
    }
}
