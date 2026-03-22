using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperCustomer
    {
        public static CustomerDto MapToCustomer(Customer customer)
        {
            return new CustomerDto
            {   
                Id = customer.Id,
                CountryId = customer.CountryId,
                Code = customer.Code,
                Name = customer.Name,
                TaxNumber = customer.TaxNumber,
                Address = customer.Address,
                PostalCode = customer.PostalCode,
                City = customer.City,
                DateCreated = customer.DateCreated,
                DateUpdated = customer.DateUpdated,
                Email = customer.Email,
                PhoneNumber = customer.PhoneNumber,
                IsEnabled = customer.IsEnabled,
                IsCustomer = customer.IsCustomer,
                IsSupplier = customer.IsSupplier,
                DueDatePeriod = customer.DueDatePeriod,
                StreetName = customer.StreetName,
                AdditionalStreetName = customer.AdditionalStreetName,
                BuildingNumber = customer.BuildingNumber,
                PlotIdentification = customer.PlotIdentification,
                CitySubdivisionName = customer.CitySubdivisionName,
                IsTaxExempt = customer.IsTaxExempt
            };
        }
    }
}
