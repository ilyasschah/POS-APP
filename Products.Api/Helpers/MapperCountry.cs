using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperCountry
    {
        public static CountryDto MapToCountry(Country country)
        {
            return new CountryDto
            {
                Name = country.Name,
                Code = country.Code
            };
        }
    }
}
