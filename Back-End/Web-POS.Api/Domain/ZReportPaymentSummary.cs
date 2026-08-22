using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ZReportPaymentSummary")]
    public class ZReportPaymentSummary
    {
        [Key]
        public int Id { get; private set; }

        public int ZReportId { get; private set; }

        public int PaymentTypeId { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalAmount { get; private set; }


        [ForeignKey(nameof(ZReportId))]
        public virtual ZReport? ZReport { get; private set; }

        [ForeignKey(nameof(PaymentTypeId))]
        public virtual PaymentType? PaymentType { get; private set; }

        public ZReportPaymentSummary() { }

        private ZReportPaymentSummary(int zReportId, int paymentTypeId, decimal totalAmount)
        {
            ZReportId = zReportId;
            PaymentTypeId = paymentTypeId;
            TotalAmount = totalAmount;
        }

        public static ZReportPaymentSummary Create(int zReportId, int paymentTypeId, decimal totalAmount)
        {
            if (zReportId <= 0) throw new ArgumentException("Invalid ZReportId");
            if (paymentTypeId <= 0) throw new ArgumentException("Invalid PaymentTypeId");
            if (totalAmount < 0) throw new ArgumentException("Amount cannot be negative");

            return new ZReportPaymentSummary(zReportId, paymentTypeId, totalAmount);
        }
    }
}