using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperFloorPlan
    {
        public static FloorPlanDto MapToDto(FloorPlan entity)
        {
            return new FloorPlanDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Color = entity.Color
            };
        }
    }
}