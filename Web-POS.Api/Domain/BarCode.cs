using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Barcode")]
    public class Barcode
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public string Value { get; private set; }
        public int ProductId { get; private set; }

        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }

        public Barcode() { }

        private Barcode(string value, int productId, int companyId)
        {
            Value = value;
            ProductId = productId;
            CompanyId = companyId;
        }

        public static Barcode Create(string value, int productId, int companyId)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("Barcode value cannot be empty.", nameof(value));
            if (productId <= 0)
                throw new ArgumentException("ProductId must be valid.", nameof(productId));
            if (companyId <= 0)
                throw new ArgumentException("CompanyId must be valid.", nameof(companyId));

            return new Barcode(value, productId, companyId);
        }

        public void UpdateValue(string? newValue)
        {
            if (!string.IsNullOrWhiteSpace(newValue))
            {
                Value = newValue;
            }
        }
    }
}