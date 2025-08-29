using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
{
    public static class MapperFloorPlanTable
    {
        public static FloorPlanTableDto MapToFloorPlanTableDto(FloorPlanTable entity)
        {
            return new FloorPlanTableDto
            {
                Id = entity.Id,
                Name = entity.Name,
                FloorPlanId = entity.FloorPlanId,
                FloorPlanName = entity.FloorPlan?.Name ?? "N/A",
                PositionX = entity.PositionX,
                PositionY = entity.PositionY,
                Width = entity.Width,
                Height = entity.Height,
                IsRound = entity.IsRound
            };
        }
    }
}