using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
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
