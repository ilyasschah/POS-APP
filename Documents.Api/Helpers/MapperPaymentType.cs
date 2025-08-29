using Documents.Api.Domain;
using Documents.Api.Models;

namespace Documents.Api.Helpers
{
    public static class MapperPaymentType
    {
        public static PaymentTypeDto MapToPaymentTypeDto(PaymentType entity)
        {
            return new PaymentTypeDto
            {
                Id = entity.Id,
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