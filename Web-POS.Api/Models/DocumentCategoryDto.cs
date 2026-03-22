namespace Api.Models
{
    public class DocumentCategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string? LanguageKey { get; set; }
        public int CompanyId { get; set; }
    }
    public class CreateDocumentCategoryRequest
    {
        public required string Name { get; set; }
        public string? LanguageKey { get; set; }
    }
}
