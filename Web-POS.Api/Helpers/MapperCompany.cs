// FILE: Products.Api.Helpers\MapperCompany.cs

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
            Address = entity.Address,
            PostalCode = entity.PostalCode,
            City = entity.City,
            CountryId = entity.CountryId,
            CountryName = entity.Country?.Name ?? "N/A",
            TaxNumber = entity.TaxNumber,
            Email = entity.Email,
            PhoneNumber = entity.PhoneNumber,
            BankAccountNumber = entity.BankAccountNumber
        };
    }
}
