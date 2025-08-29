using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
{
    public class MapperCustomerDiscount
    {
        public static CustomerDiscountDto MapToCustomerDiscount(CustomerDiscount customerDiscount)
        {
            return new CustomerDiscountDto
            {
                CustomerName = customerDiscount.Customer.Name,
                Type = customerDiscount.Type,
                Uid = customerDiscount.Uid,
                Value = customerDiscount.Value
            };
        }
    }
}
