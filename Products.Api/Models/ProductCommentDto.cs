using System.ComponentModel.DataAnnotations;

namespace Products.Api.Models
{
    public class ProductCommentDto
    {
        public string? Comment { get; set; }
        public string? ProductName { get; set; }
    }
    public class CreateProductCommentRequest
    {
        public required string Comment { get; set; }
        public required int ProductId { get; set; }
    }
    public class UpdateProductCommentRequest
    {
        [Required]
        [StringLength(1000, MinimumLength = 1)]
        public required string Comment { get; set; }
        public required int ProductId { get; set; }
    }
}
