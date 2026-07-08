namespace Api.Models
{
    public class DocumentItemTaxDto
    {
        public int DocumentItemId { get; set; }
        public int TaxId { get; set; }
        public string? TaxName { get; set; }
        public decimal Amount { get; set; }
    }

    public class CreateDocumentItemTaxRequest
    {
        public required int DocumentItemId { get; set; }
        public required int TaxId { get; set; }
    }

    public class UpdateDocumentItemTaxRequest
    {
        public required int DocumentItemId { get; set; }
        public required int TaxId { get; set; }
    }
}