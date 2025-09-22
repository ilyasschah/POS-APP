namespace Products.Api.Models
{
    public class BarcodeDto
    {
        public int Id { get; set; }
        public string? Value { get; set; }
        public string? ProductName { get; set; }
    }
    public class CreateBarcodeRequest
    {
        public required string Value { get; set; }
        public required int ProductId { get; set; }
    }
    public class UpdateBarcodeByIdRequest
    {
        public int Id { get; set; }
        public string NewBarcodeValue { get; set; }
    }
}