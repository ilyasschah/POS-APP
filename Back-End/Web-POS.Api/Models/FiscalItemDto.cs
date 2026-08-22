namespace Api.Models
{
    public class FiscalItemDto
    {
        public int PLU { get; set; }
        public string Name { get; set; } = string.Empty;
        public string VAT { get; set; } = string.Empty;
    }

    public class CreateFiscalItemRequest
    {
        public required int PLU { get; set; }
        public required string Name { get; set; }
        public required string VAT { get; set; }
    }

    public class UpdateFiscalItemRequest
    {
        public required string Name { get; set; }
        public required string VAT { get; set; }
    }
}