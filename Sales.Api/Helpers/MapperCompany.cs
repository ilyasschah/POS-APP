// FILE: Sales.Api.Helpers\MapperCompany.cs

using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers;

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
