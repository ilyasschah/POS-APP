namespace Sales.Api.Models
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
    public class UpdateCountryrequest
    {
        public required string BarcodeValue { get; set; }
        public required string NewBarcodeValue { get; set; }
    }
}