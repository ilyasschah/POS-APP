namespace Api.Models
{
    public class ApplicationPropertyDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
        public string? CompanyName { get; set; }
        public DateTime LastModified { get; set; }
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