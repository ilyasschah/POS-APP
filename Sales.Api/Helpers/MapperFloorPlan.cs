using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
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