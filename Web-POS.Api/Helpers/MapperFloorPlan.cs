using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperFloorPlan
    {
        public static FloorPlanDto MapToFloorPlanDto(FloorPlan entity)
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