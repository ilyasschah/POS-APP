namespace Api.Models
{
    public class FloorPlanDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;
    }

    public class CreateFloorPlanRequest
    {
        public required string Name { get; set; }
        public string Color { get; set; } = "Transparent";
    }

    public class UpdateFloorPlanRequest
    {
        public int Id { get; set; }
        public required string Name { get; set; }
        public required string Color { get; set; }
    }
}