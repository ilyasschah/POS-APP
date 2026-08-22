using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("PosOrderItemTax")]
    public class PosOrderItemTax
    {
        [Key]
        public int Id { get; set; }

        public int PosOrderItemId { get; set; }
        public int TaxId { get; set; }
        public int CompanyId { get; set; }

        [ForeignKey(nameof(PosOrderItemId))]
        public virtual PosOrderItem? PosOrderItem { get; set; }

        [ForeignKey(nameof(TaxId))]
        public virtual Tax? Tax { get; set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; set; }

        public PosOrderItemTax() { }

        public static PosOrderItemTax Create(int posOrderItemId, int taxId, int companyId)
        {
            return new PosOrderItemTax
            {
                PosOrderItemId = posOrderItemId,
                TaxId = taxId,
                CompanyId = companyId
            };
        }
    }
}