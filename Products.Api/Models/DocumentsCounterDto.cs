namespace Products.Api.Models
{
    public class DocumentsCounterDto
    {
        public string Name { get; set; }
        public int Value { get; set; }
    }

    public class CreateDocumentsCounterRequest
    {
        public required string Name { get; set; }
        public required int Value { get; set; }
    }

    public class UpdateDocumentsCounterRequest
    {
        public required int Value { get; set; }
    }
}