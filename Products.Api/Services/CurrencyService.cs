using Products.Api.Domain;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class CurrencyService
    {
        public CurrencyRepository _currencyRepository;
        public CurrencyService (CurrencyRepository currencyRepository)
        {
        _currencyRepository = currencyRepository;
        }
        public async Task<bool> Create(string name, string code)
        {
            var cexists = _currencyRepository.Exists(code);
            if (cexists == true)
                throw new InvalidOperationException($"A currency with the Code '{code}' already exists.");
            var newcurreency = Currency.Create(name, code);
            await _currencyRepository.Add(newcurreency);
            return true;
        }
    }
}
