using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperZReport
    {
        public static ZReportDto MapToZReportDto(ZReport entity)
        {
            return new ZReportDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                Number = entity.Number,
                DateCreated = entity.DateCreated,
                FromDocumentId = entity.FromDocumentId,
                ToDocumentId = entity.ToDocumentId,
                TotalSales = entity.TotalSales,
                TotalReturns = entity.TotalReturns,
                DiscountsGranted = entity.DiscountsGranted,
                TaxableTotal = entity.TaxableTotal,
                TotalTax = entity.TotalTax,
                GrandTotal = entity.GrandTotal,
                TotalCashIn = entity.TotalCashIn,
                TotalCashOut = entity.TotalCashOut,

                PaymentSummaries = entity.PaymentSummaries != null
                    ? entity.PaymentSummaries.Select(MapToZReportPaymentSummaryDto).ToList()
                    : new List<ZReportPaymentSummaryDto>()
            };
        }

        public static ZReportPaymentSummaryDto MapToZReportPaymentSummaryDto(ZReportPaymentSummary entity)
        {
            return new ZReportPaymentSummaryDto
            {
                Id = entity.Id,
                ZReportId = entity.ZReportId,
                PaymentTypeId = entity.PaymentTypeId,
                PaymentTypeName = entity.PaymentType?.Name,
                TotalAmount = entity.TotalAmount
            };
        }
    }
}