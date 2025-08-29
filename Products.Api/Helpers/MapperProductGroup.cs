using Products.Api.Models;
using Products.Api.Domain;

namespace Products.Api.Helpers
{
    public class MapperProductGroup
    {
        public static ProductGroupDto MapToProductGroupDetail(ProductGroup productgroup)
        {
            return new ProductGroupDto
            {
                Name = productgroup.Name,
                Color = productgroup.Color,
                Image = productgroup.Image,
                Rank = productgroup.Rank,
                ParentGroupName = productgroup.ParentGroup?.Name,
                ChildGroupNames = productgroup.ChildGroups.Select(child => child.Name).ToList()
            };
        }
    }
}
