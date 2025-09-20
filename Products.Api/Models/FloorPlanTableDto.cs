namespace Products.Api.Models
{
    public class FloorPlanTableDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int FloorPlanId { get; set; }
        public string FloorPlanName { get; set; }
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double Width { get; set; }
        public double Height { get; set; }
        public bool IsRound { get; set; }
    }

    public class CreateFloorPlanTableRequest
    {
        public required string Name { get; set; }
        public required int FloorPlanId { get; set; }
        public double? PositionX { get; set; }
        public double? PositionY { get; set; }
        public required double Width { get; set; }
        public required double Height { get; set; }
        public bool? IsRound { get; set; }
    }

    public class UpdateFloorPlanTableRequest
    {
        public required string Name { get; set; }
        public required double PositionX { get; set; }
        public required double PositionY { get; set; }
        public required double Width { get; set; }
        public required double Height { get; set; }
        public required bool IsRound { get; set; }
    }
}