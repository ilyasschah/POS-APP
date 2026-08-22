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

        // UQ_Customer_Code_PerCompany is a FILTERED unique index (WHERE Code IS NOT NULL):
        // NULL means "this customer has no code" and may repeat freely, but "" is a real
        // value, so only one row per company could ever hold it. Blank input must therefore
        // land as NULL, never as "".
        private static string? NormalizeCode(string? code)
            => string.IsNullOrWhiteSpace(code) ? null : code.Trim();

        public async Task<bool> CreateAsync(CreateCustomerRequest request, int companyId)
        {
            if (await _customerRepository.ExistsByNameAsync(request.Name, companyId))
            {
                throw new InvalidOperationException($"A customer with the name '{request.Name}' already exists.");
            }

            var code = NormalizeCode(request.Code);
            if (code != null && await _customerRepository.ExistsByCodeAsync(code, companyId))
            {
                throw new InvalidOperationException($"A customer with the code '{code}' already exists.");
            }

            var customer = Customer.Create(
                companyId,
                code,
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

            // Customer.Name is nullable in the domain, but UpdateDetails below rejects a
            // blank one anyway — hoisted here so the checks in between have a real name.
            string newName = request.Name ?? customer.Name
                ?? throw new ArgumentException("Name cannot be null or empty.", nameof(request));

            if (newName != customer.Name)
            {
                if (await _customerRepository.ExistsByNameAsync(newName, companyId))
                {
                    throw new InvalidOperationException($"A customer with the name '{newName}' already exists.");
                }
            }

            // Both callers (the customer dialog and the offline sync push) always send the
            // full row, so a blank/absent Code means "this customer has no code" — clear it.
            // Falling back to the stored value here would make clearing a code impossible.
            string? newCode = NormalizeCode(request.Code);

            if (newCode != null && newCode != customer.Code &&
                await _customerRepository.ExistsByCodeAsync(newCode, companyId))
            {
                throw new InvalidOperationException($"A customer with the code '{newCode}' already exists.");
            }

            customer.UpdateDetails(
                newCode,
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