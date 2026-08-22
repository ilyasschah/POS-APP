namespace Api.Models
{
    public class WarehouseDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int CompanyId { get; set; }
    }

    public class CreateWarehouseRequest
    {
        public required string Name { get; set; }
    }

    public class UpdateWarehouseRequest
    {
        public  int Id { get; set; }
        public required string Name { get; set; }
    }
}