using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Payment")]
    public class Payment
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }
        public int DocumentId { get; private set; }
        public int PaymentTypeId { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; private set; }

        [Column(TypeName = "date")]
        public DateTime Date { get; private set; }

        public int UserId { get; private set; }

        public int? ZReportId { get; private set; }

        public DateTime DateCreated { get; private set; }

        [ForeignKey(nameof(DocumentId))]
        public virtual Document Document { get; private set; }

        [ForeignKey(nameof(PaymentTypeId))]
        public virtual PaymentType PaymentType { get; private set; }

        [ForeignKey(nameof(UserId))]
        public virtual User User { get; private set; }

        [ForeignKey(nameof(ZReportId))]
        public virtual ZReport? ZReport { get; private set; }

        // Required by EF Core
        public Payment() { }

        private Payment(int companyId, int documentId, int paymentTypeId, decimal amount, int userId)
        {
            CompanyId = companyId;
            DocumentId = documentId;
            PaymentTypeId = paymentTypeId;
            Amount = amount;
            UserId = userId;
            DateCreated = DateTime.UtcNow;
            Date = DateTime.UtcNow.Date;
            ZReportId = null; 
        }

        public static Payment Create(int companyId, int documentId, int paymentTypeId, decimal amount, int userId)
        {
            if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
            if (documentId <= 0) throw new ArgumentException("Invalid DocumentId");
            // Negative amounts are valid for refund documents

            return new Payment(companyId, documentId, paymentTypeId, amount, userId);
        }


        public void Update(decimal amount, DateTime date)
        {
            if (ZReportId.HasValue)
                throw new InvalidOperationException("Cannot modify a payment that has already been reported on a Z-Report.");

            Amount = amount;
            Date = date.Date;
        }

        public void LockToZReport(int zReportId)
        {
            if (ZReportId.HasValue)
                throw new InvalidOperationException($"This payment is already locked to Z-Report #{ZReportId}.");

            ZReportId = zReportId;
        }
    }
}