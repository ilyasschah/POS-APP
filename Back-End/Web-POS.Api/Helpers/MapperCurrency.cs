using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperCurrency
    {
        public static CurrencyDto MapToCurrencyDto(Currency entity)
        {
            return new CurrencyDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Code = entity.Code,
            };
        }
    }
}
