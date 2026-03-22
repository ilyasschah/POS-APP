using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperCountry
    {
        public static CountryDto MapToCountry(Country country)
        {
            return new CountryDto
            {
                Id = country.Id,
                Name = country.Name,
                Code = country.Code
            };
        }
    }
}
