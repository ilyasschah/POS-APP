using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperProductComment
    {
        public static ProductCommentDto MapToProductCommentDto(ProductComment entity)
        {
            return new ProductCommentDto
            {
                Id = entity.Id,
                ProductId = entity.ProductId,
                CompanyId = entity.CompanyId,
                Comment = entity.Comment
            };
        }
    }
}
