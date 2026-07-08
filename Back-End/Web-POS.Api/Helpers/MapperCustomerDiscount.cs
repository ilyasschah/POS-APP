using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperCustomerDiscount
    {
        public static CustomerDiscountDto MapToDto(CustomerDiscount entity)
        {
            return new CustomerDiscountDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                CustomerId = entity.CustomerId,
                Type = entity.Type,
                Uid = entity.Uid,
                Value = entity.Value
            };
        }
    }
}