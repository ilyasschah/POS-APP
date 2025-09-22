namespace Products.Api.Models
{
    public class DocumentItemExpirationDateDto
    {
        public int? DocumentItemId { get; set; }
        public DateTime? ExpirationDate { get; set; }
    }
    public class CreateDocumentItemExpirationDateRequest
    {
        public int DocumentItemId { get; set; }
        public DateTime ExpirationDate { get; set; } = DateTime.UtcNow;
    }
    public class UpdateDocumentItemExpirationDateRequest
    {
        public int DocumentItemId { get; set; }
        public DateTime ExpirationDate { get; set; } = DateTime.UtcNow;
    }
}
