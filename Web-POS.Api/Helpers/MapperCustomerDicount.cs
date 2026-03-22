using Api.Domain;
using Api.Models;

namespace Api.Helpers
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
