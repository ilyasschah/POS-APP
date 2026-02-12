using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Barcode")]
    public class Barcode
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Value { get; set; }
        public int ProductId { get; set; }
        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; set; }
        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; set; }

        private Barcode(string value, int productid, int companyId)
        {
            Value = value;
            ProductId = productid;
            CompanyId = companyId;
        }
        public Barcode() { }

        public static Barcode Create(string value, int productid, int companyId)
        {
            return new Barcode(value, productid, companyId);
        }
        public void UpdateValue(string newvalue)
        {
            Value = newvalue;
        }
    }
}