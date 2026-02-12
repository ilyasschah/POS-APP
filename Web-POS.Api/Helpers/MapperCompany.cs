using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers;

public static class MapperCompany
{
    public static CompanyDto MapToCompanyDto(Company entity)
    {
        return new CompanyDto
        {
            Id = entity.Id,
            Name = entity.Name,
            CountryName = entity.Country.Name,
            Address = entity.Address,
            PostalCode = entity.PostalCode,
            City = entity.City,
            TaxNumber = entity.TaxNumber,
            Email = entity.Email,
            PhoneNumber = entity.PhoneNumber,
            BankAccountNumber = entity.BankAccountNumber,
            BankDetails = entity.BankDetails,
            StreetName = entity.StreetName,
            AdditionalStreetName = entity.AdditionalStreetName,
            BuildingNumber = entity.BuildingNumber,
            PlotIdentification = entity.PlotIdentification,
            CitySubdivisionName = entity.CitySubdivisionName,
            CountrySubentity = entity.CountrySubentity,
        };
    }
}
