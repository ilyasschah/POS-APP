using Sales.Api.Domain;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class CustomerService(CustomerRepository customerRepository)
    {
        public CustomerRepository _customerRepository = customerRepository; 
       public async Task<bool> Create(
           string code,
           string name,
           string taxNumber,
           string address,
           string postalCode,
           string city,
           int countryId,
           DateTime dateCreated,
           DateTime dateUpdated,
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
            var cexists = _customerRepository.Exists(name);
            if (cexists)
                throw new ArgumentException("Customer already exists.", nameof(name));
            var newcustomer = Customer.Create(
                code,
                name,
                taxNumber,
                address,
                postalCode,
                city,
                countryId,
                dateCreated,
                dateUpdated,
                email,
                phoneNumber,
                isEnabled,
                isCustomer,
                isSupplier,
                dueDatePeriod,
                streetName,
                additionalStreetName,
                buildingNumber,
                plotIdentification,
                citySubdivisionName,
                countrySubentity,
                isTaxExempt
            );
            await _customerRepository.Add(newcustomer);
            return true;
        }
    } 
}

