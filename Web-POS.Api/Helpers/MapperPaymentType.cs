using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperPaymentType
    {
        public static PaymentTypeDto MapToPaymentTypeDto(PaymentType entity)
        {
            return new PaymentTypeDto
            {
                Id = entity.Id,
                CompanyName = entity.Company?.Name,
                Name = entity.Name,
                Code = entity.Code,
                IsCustomerRequired = entity.IsCustomerRequired,
                IsFiscal = entity.IsFiscal,
                IsSlipRequired = entity.IsSlipRequired,
                IsChangeAllowed = entity.IsChangeAllowed,
                Ordinal = entity.Ordinal,
                IsEnabled = entity.IsEnabled,
                IsQuickPayment = entity.IsQuickPayment,
                OpenCashDrawer = entity.OpenCashDrawer,
                ShortcutKey = entity.ShortcutKey,
                MarkAsPaid = entity.MarkAsPaid
            };
        }
    }
}