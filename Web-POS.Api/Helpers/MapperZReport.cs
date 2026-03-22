using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperZReport
    {
        public static ZReportDto MapToZReport(ZReport ZReport)
        {
            return new ZReportDto
            {
                Id = ZReport.Id,
                Number = ZReport.Number,
                FromDocumentId = ZReport.FromDocumentId,
                ToDocumentId = ZReport.ToDocumentId,
                DateCreation = ZReport.DateCreated
            };
        }
    }
}
