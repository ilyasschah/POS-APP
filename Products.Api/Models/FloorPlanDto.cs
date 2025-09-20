namespace Products.Api.Models
{
    public class FloorPlanDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Color { get; set; }
    }

    public class CreateFloorPlanRequest
    {
        public required string Name { get; set; }
        public string? Color { get; set; }
    }

    public class UpdateFloorPlanRequest
    {
        public required string Name { get; set; }
        public string? Color { get; set; }
    }
}