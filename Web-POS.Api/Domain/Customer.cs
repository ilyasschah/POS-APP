using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Customer")]
    public class Customer
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public string? Code { get; private set; }
        public string Name { get; private set; }
        public string? TaxNumber { get; private set; }
        public string? Address { get; private set; }
        public string? PostalCode { get; private set; }
        public string? City { get; private set; }
        public int? CountryId { get; private set; }
        public DateTime DateCreated { get; private set; }
        public DateTime DateUpdated { get; private set; }
        public string? Email { get; private set; }
        public string? PhoneNumber { get; private set; }
        public bool IsEnabled { get; private set; }
        public bool IsCustomer { get; private set; }
        public bool IsSupplier { get; private set; }
        public int DueDatePeriod { get; private set; }
        public string? StreetName { get; private set; }
        public string? AdditionalStreetName { get; private set; }
        public string? BuildingNumber { get; private set; }
        public string? PlotIdentification { get; private set; }
        public string? CitySubdivisionName { get; private set; }
        public bool IsTaxExempt { get; private set; }

        [ForeignKey(nameof(CountryId))]
        public virtual Country? Country { get; private set; }

        private Customer(
            int companyId,
            string? code,
            string name,
            string? taxNumber,
            string? address,
            string? postalCode,
            string? city,
            int? countryId,
            DateTime dateCreated,
            string? email,
            string? phoneNumber,
            bool isEnabled,
            bool isCustomer,
            bool isSupplier,
            int dueDatePeriod,
            string? streetName,
            string? additionalStreetName,
            string? buildingNumber,
            string? plotIdentification,
            string? citySubdivisionName,
            bool isTaxExempt)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be null or empty.", nameof(name));

            CompanyId = companyId;
            Code = code;
            Name = name;
            TaxNumber = taxNumber;
            Address = address;
            PostalCode = postalCode;
            City = city;
            CountryId = countryId;
            DateCreated = dateCreated;
            DateUpdated = dateCreated; // On creation, DateUpdated is the same as DateCreated
            Email = email;
            PhoneNumber = phoneNumber;
            IsEnabled = isEnabled;
            IsCustomer = isCustomer;
            IsSupplier = isSupplier;
            DueDatePeriod = dueDatePeriod;
            StreetName = streetName;
            AdditionalStreetName = additionalStreetName;
            BuildingNumber = buildingNumber;
            PlotIdentification = plotIdentification;
            CitySubdivisionName = citySubdivisionName;
            IsTaxExempt = isTaxExempt;
        }

        public Customer() { }

        public static Customer Create(
            int companyId, string? code, string name, string? taxNumber, string? address,
            string? postalCode, string? city, int? countryId, DateTime dateCreated,
            string? email, string? phoneNumber, bool isEnabled, bool isCustomer,
            bool isSupplier, int dueDatePeriod, string? streetName, string? additionalStreetName,
            string? buildingNumber, string? plotIdentification, string? citySubdivisionName,
            bool isTaxExempt)
        {
            return new Customer(
                companyId, code, name, taxNumber, address, postalCode, city, countryId,
                dateCreated, email, phoneNumber, isEnabled, isCustomer, isSupplier,
                dueDatePeriod, streetName, additionalStreetName, buildingNumber,
                plotIdentification, citySubdivisionName, isTaxExempt);
        }

        public void UpdateDetails(
            string? code, string name, string? taxNumber, string? address,
            string? postalCode, string? city, int? countryId, string? email,
            string? phoneNumber, bool isEnabled, bool isCustomer, bool isSupplier,
            int dueDatePeriod, string? streetName, string? additionalStreetName,
            string? buildingNumber, string? plotIdentification, string? citySubdivisionName,
            bool isTaxExempt)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be null or empty.", nameof(name));

            Code = code;
            Name = name;
            TaxNumber = taxNumber;
            Address = address;
            PostalCode = postalCode;
            City = city;

            if (CountryId != countryId)
            {
                CountryId = countryId;
                Country = null;
            }

            DateUpdated = DateTime.UtcNow;
            Email = email;
            PhoneNumber = phoneNumber;
            IsEnabled = isEnabled;
            IsCustomer = isCustomer;
            IsSupplier = isSupplier;
            DueDatePeriod = dueDatePeriod;
            StreetName = streetName;
            AdditionalStreetName = additionalStreetName;
            BuildingNumber = buildingNumber;
            PlotIdentification = plotIdentification;
            CitySubdivisionName = citySubdivisionName;
            IsTaxExempt = isTaxExempt;
        }
    }
}