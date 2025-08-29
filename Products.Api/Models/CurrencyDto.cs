namespace Products.Api.Models
{
    public class CurrencyDto
    {
        public string? Name { get; set; } // "United States Dollar", "Euro"
        public string? Code { get; set; } // "USD", "EUR"
    }
    public class CreateCurrencyRequest
    {
        public required string Name { get; set; }
        public required string Code { get; set; }
    }
}
