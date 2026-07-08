using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class CustomerService
    {
        private readonly CustomerRepository _customerRepository;

        public CustomerService(CustomerRepository customerRepository)
        {
            _customerRepository = customerRepository;
        }

        public async Task<bool> CreateAsync(CreateCustomerRequest request, int companyId)
        {
            if (await _customerRepository.ExistsByNameAsync(request.Name, companyId))
            {
                throw new InvalidOperationException($"A customer with the name '{request.Name}' already exists.");
            }

            var customer = Customer.Create(
                companyId,
                request.Code,
                request.Name,
                request.TaxNumber,
                request.Address,
                request.PostalCode,
                request.City,
                request.CountryId,
                request.DateCreated != default ? request.DateCreated : DateTime.UtcNow,
                request.Email,
                request.PhoneNumber,
                request.IsEnabled,
                request.IsCustomer,
                request.IsSupplier,
                request.DueDatePeriod,
                request.StreetName,
                request.AdditionalStreetName,
                request.BuildingNumber,
                request.PlotIdentification,
                request.CitySubdivisionName,
                request.IsTaxExempt
            );

            await _customerRepository.AddCustomerAsync(customer);
            return true;
        }

        public async Task<bool> UpdateAsync(UpdateCustomerRequest request, int companyId)
        {
            if (request.Id == null)
            {
                throw new ArgumentException("Customer ID is required.");
            }

            var customer = await _customerRepository.GetCustomerByIdAsync(request.Id.Value, companyId);
            if (customer == null)
            {
                throw new KeyNotFoundException($"Customer with ID {request.Id} not found.");
            }

            string newName = request.Name ?? customer.Name;

            if (newName != customer.Name)
            {
                if (await _customerRepository.ExistsByNameAsync(newName, companyId))
                {
                    throw new InvalidOperationException($"A customer with the name '{newName}' already exists.");
                }
            }

            customer.UpdateDetails(
                request.Code ?? customer.Code,
                newName,
                request.TaxNumber ?? customer.TaxNumber,
                request.Address ?? customer.Address,
                request.PostalCode ?? customer.PostalCode,
                request.City ?? customer.City,
                request.CountryId ?? customer.CountryId,
                request.Email ?? customer.Email,
                request.PhoneNumber ?? customer.PhoneNumber,
                request.IsEnabled ?? customer.IsEnabled,
                request.IsCustomer ?? customer.IsCustomer,
                request.IsSupplier ?? customer.IsSupplier,
                request.DueDatePeriod ?? customer.DueDatePeriod,
                request.StreetName ?? customer.StreetName,
                request.AdditionalStreetName ?? customer.AdditionalStreetName,
                request.BuildingNumber ?? customer.BuildingNumber,
                request.PlotIdentification ?? customer.PlotIdentification,
                request.CitySubdivisionName ?? customer.CitySubdivisionName,
                request.IsTaxExempt ?? customer.IsTaxExempt
            );

            await _customerRepository.UpdateCustomerAsync(customer);
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var customer = await _customerRepository.GetCustomerByIdAsync(id, companyId);
            if (customer == null)
            {
                throw new KeyNotFoundException($"Customer with ID {id} not found.");
            }

            await _customerRepository.DeleteAsync(customer);
            return true;
        }
    }
}