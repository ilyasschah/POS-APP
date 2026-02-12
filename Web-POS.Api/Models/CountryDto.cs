namespace Products.Api.Models
{
    public class CountryDto
    {
        public string? Name { get; set; }
        public string? Code { get; set; }
    }
    public class CreateCountryRequest
    {
        public required string Name { get; set; }
        public required string Code { get; set; }
    }
    public class UpdateCountryRequest
    {
        public required string Name { get; set; }
        public required string Code { get; set; }
    }
}