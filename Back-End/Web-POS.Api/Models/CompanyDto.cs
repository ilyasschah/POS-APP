namespace Api.Models;

public class CompanyDto
{
    public int Id { get; set; }
    public string Name { get; set; }
    public byte[]? Logo { get; set; }
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

    // SaaS provisioning (Pillar 1/2) — optional; the admin portal sets these.
    // When omitted, sensible defaults apply (see CompanyService).
    public int? SeatAllowance { get; set; }
    public int? SubscriptionDays { get; set; }
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

/// <summary>
/// Body of POST /api/Company/ResetData. Every flag defaults to FALSE so an
/// empty or malformed body resets nothing — the controller rejects a selection
/// with no flags set rather than reading it as "all of it".
/// </summary>
public class ResetCompanyDataRequest
{
    public required int CompanyId { get; set; }

    /// Also clears Documents — DocumentItem and PosOrderItem both hold a FK to
    /// Product, so the sales rows cannot outlive the catalogue.
    public bool Products { get; set; }

    /// Also clears Documents — Document and PosOrder both reference Customer.
    public bool Customers { get; set; }

    /// Sales history and live orders: documents, payments, POS orders, voids
    /// and Z-reports. Bookings survive with their order link detached.
    public bool Documents { get; set; }

    /// Every company-scoped table except Users, their device PINs, and the
    /// company's saved settings.
    public bool Everything { get; set; }
}
