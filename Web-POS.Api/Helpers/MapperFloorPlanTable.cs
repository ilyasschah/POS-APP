using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperFloorPlanTable
    {
        public static FloorPlanTableDto MapToDto(FloorPlanTable entity)
        {
            return new FloorPlanTableDto
            {
                Id = entity.Id,
                FloorPlanId = entity.FloorPlanId,
                Name = entity.Name,
                Status = entity.Status,
                PositionX = entity.PositionX,
                PositionY = entity.PositionY,
                Width = entity.Width,
                Height = entity.Height,
                IsRound = entity.IsRound
            };
        }
    }
}