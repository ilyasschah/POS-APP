namespace Api.Models
{
    public class DocumentItemExpirationDateDto
    {
        public int DocumentItemId { get; set; }
        public DateTime ExpirationDate { get; set; }
    }

    public class CreateDocumentItemExpirationDateRequest
    {
        public required int DocumentItemId { get; set; }
        public required DateTime ExpirationDate { get; set; }
    }

    public class UpdateDocumentItemExpirationDateRequest
    {
        public required int DocumentItemId { get; set; }
        public required DateTime ExpirationDate { get; set; }
    }
}