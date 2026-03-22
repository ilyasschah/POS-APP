using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Keyless]
    [Table("DocumentItemTax")]
    public class DocumentItemTax
    {
        public  int DocumentItemId  { get; set; }
        public int TaxID { get; set; }
        public decimal Amount { get; set; }
        [ForeignKey(nameof(DocumentItemId))]
        public virtual DocumentItem DocumentItem { get; set; }
        [ForeignKey(nameof(TaxID))]
        public virtual Tax Tax { get; set; }
        private DocumentItemTax(int documentItemId, int taxId, decimal amount)
        {
            DocumentItemId = documentItemId;
            TaxID = taxId;
            Amount = amount;
        }
        public DocumentItemTax() { }
        public static DocumentItemTax Create(
            int documentItemId,
            int taxId,
            decimal amount)
        {
            return new DocumentItemTax(
                documentItemId,
                taxId,
                amount);
        }
        public void UpdateAmount(decimal amount)
        {
            Amount = amount;
        }
    }
}
