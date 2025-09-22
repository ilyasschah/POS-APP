namespace Products.Api.Models
{
    public class ProductCommentDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string Comment { get; set; } = default!;
    }

    public class CreateProductCommentRequest
    {
        public required int ProductId { get; set; }
        public required string Comment { get; set; }
    }

    public class UpdateProductCommentRequest
    {
        public required int ProductId { get; set; }
        public required string Comment { get; set; }
    }
}
