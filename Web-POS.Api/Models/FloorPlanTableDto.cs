namespace Api.Models
{
    public class FloorPlanTableDto
    {
        public int Id { get; set; }
        public int FloorPlanId { get; set; }
        public string? Name { get; set; }
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double Width { get; set; }
        public double Height { get; set; }
        public bool IsRound { get; set; }
    }

    public class CreateFloorPlanTableRequest
    {
        public int FloorPlanId { get; set; }
        public required string Name { get; set; }
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double Width { get; set; }
        public double Height { get; set; }
        public bool IsRound { get; set; }
    }

    public class UpdateTableGeometryRequest
    {
        public int Id { get; set; }
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double Width { get; set; }
        public double Height { get; set; }
    }
}