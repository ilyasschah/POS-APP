using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperProductComment
    {
        public static ProductCommentDto MapToProductComment(ProductComment productComment)
        {
            return new ProductCommentDto
            {
                Comment = productComment.Comment,
                ProductName = productComment.Product.Name
            };
        }
    }
}
