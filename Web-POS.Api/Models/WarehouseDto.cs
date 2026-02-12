namespace Products.Api.Models
{
    public class WarehouseDto
    {
        public string? Name { get; set; }
        public int CompanyId { get; set; }
    }
    public class CreateWarehouseRequest
    {
        public required string Name { get; set; }
        public int CompanyId { get; set; }
    }
}
