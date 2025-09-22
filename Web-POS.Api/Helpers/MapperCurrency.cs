using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperCurrency
    {
        public static CurrencyDto MapToCurrencyDto(Currency entity)
        {
            return new CurrencyDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Code = entity.Code
            };
        }
    }
}
