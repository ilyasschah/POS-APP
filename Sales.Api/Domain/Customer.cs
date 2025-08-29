using MediatR;
using Products.Api.Domain;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Sales.Api.Domain
{
    [Table("Customer")]
    public class Customer
    {
        [Key]
        public int Id { get; set; }
        public string? Code { get; set; }
        public string Name { get; set; }
        public string? TaxNumber { get; set; }
        public string? Address { get; set; }
        public string? PostalCode { get; set; }
        public string? City { get; set; }
        public int? CountryId { get; set; }
        public DateTime DateCreated { get; set; }
        public DateTime DateUpdated { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsCustomer { get; set; }
        public bool IsSupplier { get; set; }
        public int DueDatePeriod { get; set; }
        public string? StreetName { get; set; }
        public string? AdditionalStreetName { get; set; }
        public string? BuildingNumber { get; set; }
        public string? PlotIdentification { get; set; }
        public string? CitySubdivisionName { get; set; }
        public string? CountrySubentity { get; set; }
        public bool IsTaxExempt { get; set; }

        [ForeignKey(nameof(CountryId))]
        public virtual Country Country { get; set; }
        private Customer(
            string code,
            string name,
            string taxNumber,
            string address,
            string postalCode,
            string city,
            int countryid,
            DateTime createdate,
            DateTime updateddate,
            string email,
            string phoneNumber,
            bool isEnabled,
            bool isCustomer,
            bool isSupplier,
            int dueDatePeriod,
            string streetName,
            string additionalStreetName,
            string buildingNumber,
            string plotIdentification,
            string citySubdivisionName,
            string countrySubentity,
            bool isTaxExempt)
        {
            Code = code;
            Name = name;
            TaxNumber = taxNumber;
            Address = address;
            PostalCode = postalCode;
            City = city;
            CountryId = countryid;
            DateCreated = createdate;
            DateUpdated = updateddate;
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
            CountrySubentity = countrySubentity;
            IsTaxExempt = isTaxExempt;
        }

        public Customer() { }

        public static Customer Create(string code, string name, string taxNumber, string address, string postalCode, string city, int countryId, DateTime createdate, DateTime updateddate, string email, string phoneNumber, bool isEnabled, bool isCustomer, bool isSupplier, int dueDatePeriod, string streetName, string additionalStreetName, string buildingNumber, string plotIdentification, string citySubdivisionName, string countrySubentity, bool isTaxExempt)
        {
            if (name == null)
            {
                throw new ArgumentNullException(nameof(name), "Name cannot be null.");
            }
            return new Customer(code, name, taxNumber, address, postalCode, city, countryId, createdate, updateddate, email, phoneNumber, isEnabled, isCustomer, isSupplier, dueDatePeriod, streetName, additionalStreetName, buildingNumber, plotIdentification, citySubdivisionName, countrySubentity, isTaxExempt);
        }
        public void UpdateName(string newName)
        {
            if (string.IsNullOrWhiteSpace(newName))
            {
                throw new ArgumentException("Name cannot be null or whitespace.", nameof(newName));
            }
            Name = newName;
        }
    }
}