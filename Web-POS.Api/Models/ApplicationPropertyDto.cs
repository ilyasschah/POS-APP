namespace Products.Api.Models
{
    public class ApplicationPropertyDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Value { get; set; }
        public string? CompanyName { get; set; }
    }

    public class CreateApplicationPropertyRequest
    {
        public required string Name { get; set; }
        public required string Value { get; set; }
    }

    public class UpdateApplicationPropertyRequest
    {
        public required int Id { get; set; }
        public required string NewValue { get; set; }
    }
}