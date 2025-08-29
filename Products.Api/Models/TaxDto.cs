namespace Products.Api.Models
{
    public class TaxDto
    {
        public string? Name { get; set; }
        public decimal? Rate { get; set; }
        public string? Code { get; set; }
        public bool? IsFixed { get; set; }
        public bool? IsTaxOnTotal { get; set; }
        public bool? IsEnabled { get; set; }
    }
    public class CreateTaxRequestDto
    {
        public required string Name { get; set; }
        public required decimal Rate { get; set; }
        public string? Code { get; set; }
        public required bool IsFixed { get; set; }
        public required bool IsTaxOnTotal { get; set; }
        public required bool IsEnabled { get; set; }
    }
    public class UpdateTaxRequestDto
    {
        public required string Name { get; set; }
        public  decimal Rate { get; set; }
        public string? Code { get; set; }
        public bool IsFixed { get; set; }
        public bool IsTaxOnTotal { get; set; }
        public bool IsEnabled { get; set; }
    }
}
