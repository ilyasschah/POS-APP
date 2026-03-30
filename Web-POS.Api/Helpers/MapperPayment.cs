using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPayment
    {
        public static PaymentDto? MapToPaymentDto(Payment? entity)
        {
            if (entity == null) return null;
            return new PaymentDto
            {
                Id = entity.Id,
                DocumentId = entity.DocumentId,
                PaymentTypeId = entity.PaymentTypeId,
                PaymentTypeName = entity.PaymentType?.Name,
                Amount = entity.Amount,
                Date = entity.Date,
                UserId = entity.UserId,
                UserName = entity.User?.Username,
                ZReportId = entity.ZReportId,
                DateCreated = entity.DateCreated
            };
        }
    }
}