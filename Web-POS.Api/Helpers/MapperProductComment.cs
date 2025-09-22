using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperProductComment
    {
        public static ProductCommentDto MapToProductCommentDto(ProductComment entity)
        {
            return new ProductCommentDto
            {
                Id = entity.Id,
                ProductId = entity.ProductId,
                Comment = entity.Comment
            };
        }
    }
}
