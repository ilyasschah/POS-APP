namespace Api.Models
{
    public class BarcodeDto
    {
        public int Id { get; set; }
        public string Value { get; set; } = string.Empty;
        public int ProductId { get; set; }
        public string ProductName { get; set; } = string.Empty;
    }

    public class CreateBarcodeRequest
    {
        public required int ProductId { get; set; }
        public required string Value { get; set; }
    }

    public class UpdateBarcodeRequest
    {
        public required int Id { get; set; }
        public required string Value { get; set; }
    }
}