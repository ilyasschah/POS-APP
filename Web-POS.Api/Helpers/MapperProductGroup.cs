using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperProductGroup
    {
        public static ProductGroupDto MapToDto(ProductGroup entity)
        {
            if (entity == null) return null;

            return new ProductGroupDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                Name = entity.Name,
                ParentGroupId = entity.ParentGroupId,
                ParentGroupName = entity.ParentGroup?.Name,
                Color = entity.Color ?? "Transparent",
                Image = entity.Image,
                Rank = entity.Rank
            };
        }
    }
}