using Sales.Api.Domain;
using Sales.Api.Repository;

namespace Sales.Api.Services
{
    public class CustomerDiscountService(CustomerDiscountRepository customerdiscountRepository)
    {
        public CustomerDiscountRepository _customerdiscountRepository = customerdiscountRepository;

        public async Task<bool> Create(int customerid, int type, int uid, decimal value)
        {
            var newstock = CustomerDiscount.Create(customerid, type, uid, value);
            await _customerdiscountRepository.Add(newstock);
            return true;
        }
    }
}
