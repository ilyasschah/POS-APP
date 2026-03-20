using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Company")]
    public class Company
    {
        [Key]
        public int Id { get; private set; }
        public string Name { get; private set; }
        public string? Address { get; private set; }
        public string? PostalCode { get; private set; }
        public string? City { get; private set; }
        public int CountryId { get; private set; }
        public string? TaxNumber { get; private set; }
        public string? Email { get; private set; }
        public string? PhoneNumber { get; private set; }
        public byte[]? Logo { get; private set; }
        public string? BankAccountNumber { get; private set; }
        public string? BankDetails { get; private set; }
        public string? StreetName { get; private set; }
        public string? AdditionalStreetName { get; private set; }
        public string? BuildingNumber { get; private set; }
        public string? PlotIdentification { get; private set; }
        public string? CitySubdivisionName { get; private set; }
        public string? CountrySubentity { get; private set; }

        [ForeignKey(nameof(CountryId))]
        public virtual Country Country { get; set; }

        public Company() { }

        private Company(string name, int countryId, string? address, string? postalCode, string? city, string? taxNumber, string? email, string? phoneNumber, string? bankAccountNumber, string? bankDetails, string? streetName, string? additionalStreetName, string? buildingNumber, string? plotIdentification, string? citySubdivisionName, string? countrySubentity)
        {
            Name = name;
            CountryId = countryId;
            Address = address;
            PostalCode = postalCode;
            City = city;
            TaxNumber = taxNumber;
            Email = email;
            PhoneNumber = phoneNumber;
            BankAccountNumber = bankAccountNumber;
            BankDetails = bankDetails;
            StreetName = streetName;
            AdditionalStreetName = additionalStreetName;
            BuildingNumber = buildingNumber;
            PlotIdentification = plotIdentification;
            CitySubdivisionName = citySubdivisionName;
            CountrySubentity = countrySubentity;
        }

        public static Company Create(string name, int countryId, string? address, string? postalCode, string? city, string? taxNumber, string? email, string? phoneNumber, string? bankAccountNumber, string? bankDetails, string? streetName, string? additionalStreetName, string? buildingNumber, string? plotIdentification, string? citySubdivisionName, string? countrySubentity)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Company name cannot be empty.", nameof(name));
            if (countryId <= 0)
                throw new ArgumentException("Invalid CountryId.", nameof(countryId));

            return new Company(
                name, countryId, address, postalCode, city, taxNumber, email, phoneNumber,
                bankAccountNumber, bankDetails, streetName, additionalStreetName,
                buildingNumber, plotIdentification, citySubdivisionName, countrySubentity
            );
        }

        public void UpdateDetails(string name, int countryId, string? address, string? postalCode, string? city, string? taxNumber, string? email, string? phoneNumber, string? bankAccountNumber, string? bankDetails, string? streetName, string? additionalStreetName, string? buildingNumber, string? plotIdentification, string? citySubdivisionName, string? countrySubentity)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Company name cannot be empty.", nameof(name));
            if (countryId <= 0)
                throw new ArgumentException("Invalid CountryId.", nameof(countryId));

            Name = name;
            CountryId = countryId;
            Address = address;
            PostalCode = postalCode;
            City = city;
            TaxNumber = taxNumber;
            Email = email;
            PhoneNumber = phoneNumber;
            BankAccountNumber = bankAccountNumber;
            BankDetails = bankDetails;
            StreetName = streetName;
            AdditionalStreetName = additionalStreetName;
            BuildingNumber = buildingNumber;
            PlotIdentification = plotIdentification;
            CitySubdivisionName = citySubdivisionName;
            CountrySubentity = countrySubentity;
        }

        public void UpdateLogo(byte[]? logo)
        {
            Logo = logo;
        }
    }
}