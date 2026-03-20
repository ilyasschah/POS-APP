namespace Products.Api.Models;

public class CompanyDto
{
    public int Id { get; set; }
    public string Name { get; set; }
    public int CountryId { get; set; }
    public string? CountryName { get; set; }
    public string? Address { get; set; }
    public string? PostalCode { get; set; }
    public string? City { get; set; }
    public string? TaxNumber { get; set; }
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankDetails { get; set; }
    public string? StreetName { get; set; }
    public string? AdditionalStreetName { get; set; }
    public string? BuildingNumber { get; set; }
    public string? PlotIdentification { get; set; }
    public string? CitySubdivisionName { get; set; }
    public string? CountrySubentity { get; set; }
}

public class CreateCompanyRequest
{
    public required string Name { get; set; }
    public required int CountryId { get; set; }
    public string? Address { get; set; }
    public string? PostalCode { get; set; }
    public string? City { get; set; }
    public string? TaxNumber { get; set; }
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankDetails { get; set; }
    public string? StreetName { get; set; }
    public string? AdditionalStreetName { get; set; }
    public string? BuildingNumber { get; set; }
    public string? PlotIdentification { get; set; }
    public string? CitySubdivisionName { get; set; }
    public string? CountrySubentity { get; set; }
}

public class UpdateCompanyRequest
{
    public required int Id { get; set; }
    public required string Name { get; set; }
    public required int CountryId { get; set; }
    public string? Address { get; set; }
    public string? PostalCode { get; set; }
    public string? City { get; set; }
    public string? TaxNumber { get; set; }
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankDetails { get; set; }
    public string? StreetName { get; set; }
    public string? AdditionalStreetName { get; set; }
    public string? BuildingNumber { get; set; }
    public string? PlotIdentification { get; set; }
    public string? CitySubdivisionName { get; set; }
    public string? CountrySubentity { get; set; }
}
public class UpdateCompanyLogoRequest
{
    public required int Id { get; set; }
    public required byte[] Logo { get; set; }
}
