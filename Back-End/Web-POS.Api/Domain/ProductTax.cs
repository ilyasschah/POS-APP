using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ProductTax")]
    public class ProductTax
    {
        public int ProductId { get; set; }
        public int TaxId { get; set; }

        [ForeignKey(nameof(ProductId))]
        public virtual Product? Product { get; set; }

        public int CompanyId { get; set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        [ForeignKey(nameof(TaxId))]
        public virtual Tax? Tax { get; set; }

        private ProductTax(int productId, int taxId, int companyId)
        {
            if (companyId <= 0)
                throw new ArgumentException("Company ID must be greater than zero.", nameof(companyId));

            ProductId = productId;
            TaxId = taxId;
            CompanyId = companyId;
        }

        public ProductTax() { }

        public static ProductTax Create(int productId, int taxId, int companyId)
        {
            return new ProductTax(productId, taxId, companyId);
        }

    }
}