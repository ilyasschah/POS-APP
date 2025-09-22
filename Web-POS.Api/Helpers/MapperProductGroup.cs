using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperProductGroup
    {
        public static ProductGroupDto MapToProductGroupDto(ProductGroup entity)
        {
            return new ProductGroupDto
            {
                Id = entity.Id,
                Name = entity.Name,
                ParentGroupId = entity.ParentGroupId,
                Color = entity.Color,
                Image = entity.Image,
                Rank = entity.Rank
            };
        }
    }
}
