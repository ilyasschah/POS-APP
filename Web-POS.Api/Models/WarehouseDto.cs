namespace Products.Api.Models
{
    public class WarehouseDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string? CompanyName { get; set; }
    }

    public class CreateWarehouseRequest
    {
        public required string Name { get; set; }
    }

    public class UpdateWarehouseRequest
    {
        public required int Id { get; set; }
        public required string Name { get; set; }
    }
}