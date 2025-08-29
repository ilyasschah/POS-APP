using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ProductComment")]
    public class ProductComment
    {
        [Key]
        public int Id { get; set; }
        public string Comment { get; set; }
        public int ProductId { get; set; }
        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; set; }


        private ProductComment(string comment, int productId)
        {
            Comment = comment.Trim();
            ProductId = productId;
        }

        public ProductComment() { }
        public static ProductComment Create(string comment,int productId)
        {
            if (string.IsNullOrWhiteSpace(comment))
                throw new ArgumentException("Comment cannot be empty", nameof(comment));
            return new ProductComment(comment, productId);
        }

        public void UpdateComment(string newComment)
        {
            if (string.IsNullOrWhiteSpace(newComment))
                throw new ArgumentException("Comment cannot be empty", nameof(newComment));
            Comment = newComment.Trim();
        }
    }
}