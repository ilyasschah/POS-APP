namespace Api.Models
{
    public class CurrencyDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public string? Code { get; set; }
    }

    public class CreateCurrencyRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
    }

    public class UpdateCurrencyRequest
    {
        public required string Name { get; set; }
        public string? Code { get; set; }
    }
}
