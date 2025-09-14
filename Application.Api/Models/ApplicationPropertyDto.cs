namespace Products.Api.Models
{
    public class ApplicationPropertyDto
    {
        public string Name { get; set; } = default!;
        public string? Value { get; set; }
    }

    public class CreateApplicationPropertyRequest
    {
        public required string Name { get; set; }
        public string? Value { get; set; }
    }

    public class UpdateApplicationPropertyRequest
    {
        public required string Name { get; set; }   // allow rename of the key
        public string? Value { get; set; }
    }
}
