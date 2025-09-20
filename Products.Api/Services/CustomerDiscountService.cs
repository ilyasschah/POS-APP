using Products.Api.Domain;
using Products.Api.Repository;

namespace Products.Api.Services
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
