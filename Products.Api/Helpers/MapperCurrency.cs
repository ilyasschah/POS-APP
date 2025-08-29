using Products.Api.Models;
using Products.Api.Domain;

namespace Products.Api.Helpers
{
    public class MapperCurrency
    {
        public static CurrencyDto MapToCurrency(Currency currencies)
        {
            return new CurrencyDto
            {
                Name = currencies.Name,
                Code = currencies.Code
            };
        }
    }
}
