namespace Documents.Api.Models
{
    public class DocumentItemTaxDto
    {
        public int DocumentItemId { get; set; }
        public int TaxID { get; set; }
        public string? TaxName { get; set; }
        public Decimal Amount { get; set; }
    }
    public class CreateDocumentItemTaxRequest
    {
        public int DocumentItemId { get; set; }
        public int TaxId { get; set; }
        public Decimal Amount { get; set; } = 0;
    }
    public class UpdateDocumentItemTaxRequest
    {
        public int DocumentItemId { get; set; }
        public Decimal Amount { get; set; }
    }
}
