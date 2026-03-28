namespace Api.Models
{
    public class ProductCommentDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string Comment { get; set; } = default!;
        public int CompanyId { get; set; }
    }

    public class CreateProductCommentRequest
    {
        public required int ProductId { get; set; }
        public required string Comment { get; set; }
    }

    public class UpdateProductCommentRequest
    {
        public int Id { get; set; }
        public int? ProductId { get; set; }
        public string? Comment { get; set; }
    }
}
