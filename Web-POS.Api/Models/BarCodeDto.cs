namespace Api.Models
{
    public class BarcodeDto
    {
        public int Id { get; set; }
        public string? Value { get; set; }
        public int ProductId { get; set; }
        public string? ProductName { get; set; }
        public int CompanyId { get; set; }
        public string? CompanyName { get; set; }
    }
    public class CreateBarcodeRequest
    {
        public required int ProductId { get; set; }
        public required string Value { get; set; }
        
    }
    public class UpdateBarcodeRequest
    {   
        public required int Id { get; set; }
        public required string NewBarcodeValue { get; set; }
    }
    public class DeleteBarcodeRequest
    {
        public required string Value { get; set; }
    }
}