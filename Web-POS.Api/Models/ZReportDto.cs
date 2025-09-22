namespace Products.Api.Models
{
    public class ZReportDto
    {
        public int? Id { get; set; }
        public int? Number { get; set; }
        public int? FromDocumentId { get; set; }
        public int? ToDocumentId { get; set; }
        public DateTime? DateCreation { get; set; }
    }
    public class CreateZReportRequest
    {
        public required int Number { get; set; }
        public required int FromDocumentId { get; set; }
        public required int ToDocumentId { get; set; }
    }
}
