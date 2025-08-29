using Documents.Api.Domain;
using Documents.Api.Models;

namespace Documents.Api.Helpers
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
