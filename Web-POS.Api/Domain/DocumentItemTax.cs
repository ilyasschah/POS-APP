using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentItemTax")]
    public class DocumentItemTax
    {
        public int DocumentItemId { get; private set; }
        public int TaxId { get; private set; }
        public decimal Amount { get; private set; }
        public int CompanyId { get; private set; }

        [ForeignKey(nameof(DocumentItemId))]
        public virtual DocumentItem? DocumentItem { get; private set; }

        [ForeignKey(nameof(TaxId))]
        public virtual Tax? Tax { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public DocumentItemTax() { }

        private DocumentItemTax(int documentItemId, int taxId, decimal amount, int companyId)
        {
            DocumentItemId = documentItemId;
            TaxId = taxId;
            Amount = amount;
            CompanyId = companyId;
        }

        public static DocumentItemTax Create(int documentItemId, int taxId, decimal amount, int companyId)
        {
            if (documentItemId <= 0)
                throw new ArgumentException("DocumentItemId must be valid.", nameof(documentItemId));
            if (taxId <= 0)
                throw new ArgumentException("TaxId must be valid.", nameof(taxId));
            if (companyId <= 0)
                throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (amount < 0)
                throw new ArgumentException("Amount cannot be negative.", nameof(amount));

            return new DocumentItemTax(documentItemId, taxId, amount, companyId);
        }

        public void UpdateAmount(decimal? amount)
        {
            if (amount.HasValue && amount.Value >= 0)
            {
                Amount = amount.Value;
            }
        }
    }
}