namespace Products.Api.Models
{
    public class TemplateDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public string Value { get; set; } = default!;
    }

    public class CreateTemplateRequest
    {
        public required string Name { get; set; }
        public required string Value { get; set; }
    }

    public class UpdateTemplateRequest
    {
        public required string Name { get; set; }
        public required string Value { get; set; }
    }
}
