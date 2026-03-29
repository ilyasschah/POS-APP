using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentItemExpirationDate")]
    public class DocumentItemExpirationDate
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)] // Tells EF Core the ID is provided manually, not auto-incremented
        public int DocumentItemId { get; private set; }

        [Column(TypeName = "date")] // Ensures it maps specifically to the SQL 'date' type, ignoring time
        public DateTime ExpirationDate { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(DocumentItemId))]
        public virtual DocumentItem DocumentItem { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }

        // Required by EF Core
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