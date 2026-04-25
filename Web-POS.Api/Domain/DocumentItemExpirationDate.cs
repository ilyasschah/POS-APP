using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentItemExpirationDate")]
    public class DocumentItemExpirationDate
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int DocumentItemId { get; private set; }

        [Column(TypeName = "date")]
        public DateTime ExpirationDate { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(DocumentItemId))]
        public virtual DocumentItem? DocumentItem { get; private set; }

        public virtual Company? Company { get; private set; }

        public DocumentItemExpirationDate() { }

        private DocumentItemExpirationDate(int documentItemId, DateTime expirationDate, int companyId)
        {
            DocumentItemId = documentItemId;
            ExpirationDate = expirationDate;
            CompanyId = companyId;
        }

        public static DocumentItemExpirationDate Create(int documentItemId, DateTime expirationDate, int companyId)
        {
            if (documentItemId <= 0)
                throw new ArgumentException("DocumentItemId must be valid.", nameof(documentItemId));
            if (companyId <= 0)
                throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (expirationDate.Date < DateTime.UtcNow.Date)
                 throw new ArgumentException("Expiration date cannot be in the past.", nameof(expirationDate));

            return new DocumentItemExpirationDate(documentItemId, expirationDate, companyId);
        }

        public void UpdateExpirationDate(DateTime newExpirationDate)
        {
            ExpirationDate = newExpirationDate;
        }
    }
}