using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ProductComment")]
    public class ProductComment
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }

        [Required]
        [ForeignKey(nameof(Product))]
        public int ProductId { get; set; }

        [Required]
        public string Comment { get; set; } = default!;
        public Product? Product { get; set; }
        

        private ProductComment(int productId, string comment, int companyId)
        {
            ProductId = productId;
            Comment = comment;
            CompanyId = companyId;
        }
        public ProductComment() { }
        public static ProductComment Create(int productId, string comment, int companyId)
            => new(productId, comment, companyId);
        public void Update(int? productId, string? comment)
        {
            if (productId.HasValue)
                ProductId = productId.Value;
            if (!string.IsNullOrWhiteSpace(comment))
                Comment = comment;
        }
    }
}
