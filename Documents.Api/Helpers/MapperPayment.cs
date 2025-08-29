using Documents.Api.Domain;
using Documents.Api.Models;

namespace Documents.Api.Helpers
{
    public static class MapperPayment
    {
        public static PaymentDto MapToPaymentDto(Payment entity)
        {
            return new PaymentDto
            {
                Id = entity.Id,
                DocumentId = entity.DocumentId,
                PaymentTypeId = entity.PaymentTypeId,
                PaymentTypeName = entity.PaymentType?.Name ?? "N/A",
                Amount = entity.Amount,
                Date = entity.Date,
                UserId = entity.UserId,
                UserName = entity.User?.Username ?? "N/A",
                ZReportId = entity.ZReportId,
                DateCreated = entity.DateCreated
            };
        }
    }
}