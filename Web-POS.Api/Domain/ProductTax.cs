using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ProductTax")]
    public class ProductTax
    {
        public int ProductId { get; set; }
        public int TaxId { get; set; }
        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; set; }

        [ForeignKey(nameof(TaxId))]
        public virtual Tax Tax { get; set; }
        private ProductTax(int productId, int taxId)
        {
            ProductId = productId;
            TaxId = taxId;
        }
        public ProductTax() { }

        public static ProductTax Create(int productId, int taxId)
        {
            return new ProductTax(productId, taxId);
        }
    }
}