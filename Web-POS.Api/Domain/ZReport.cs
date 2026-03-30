using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ZReport")]
    public class ZReport
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }
        public int Number { get; private set; }
        public DateTime DateCreated { get; private set; }

        public int FromDocumentId { get; private set; }
        public int ToDocumentId { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalSales { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalReturns { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal DiscountsGranted { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TaxableTotal { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalTax { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal GrandTotal { get; private set; }

        // --- NAVIGATION PROPERTIES ---

        // Links the payments that were locked into this specific Z-Report
        public virtual ICollection<Payment> Payments { get; private set; } = new List<Payment>();

        // Links the grouped payment summaries (e.g., Cash: $100, Credit: $50)
        public virtual ICollection<ZReportPaymentSummary> PaymentSummaries { get; private set; } = new List<ZReportPaymentSummary>();


        // Required by EF Core
        public ZReport() { }

        private ZReport(
            int companyId,
            int number,
            int fromDocumentId,
            int toDocumentId,
            decimal totalSales,
            decimal totalReturns,
            decimal discountsGranted,
            decimal taxableTotal,
            decimal totalTax,
            decimal grandTotal)
        {
            CompanyId = companyId;
            Number = number;
            FromDocumentId = fromDocumentId;
            ToDocumentId = toDocumentId;
            TotalSales = totalSales;
            TotalReturns = totalReturns;
            DiscountsGranted = discountsGranted;
            TaxableTotal = taxableTotal;
            TotalTax = totalTax;
            GrandTotal = grandTotal;
            DateCreated = DateTime.UtcNow;
        }

        public static ZReport Create(
            int companyId,
            int number,
            int fromDocumentId,
            int toDocumentId,
            decimal totalSales,
            decimal totalReturns,
            decimal discountsGranted,
            decimal taxableTotal,
            decimal totalTax,
            decimal grandTotal)
        {
            if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
            if (number <= 0) throw new ArgumentException("Invalid Report Number");
            if (fromDocumentId <= 0 || toDocumentId <= 0 || fromDocumentId > toDocumentId)
                throw new ArgumentException("Invalid Document ID Range");

            return new ZReport(
                companyId,
                number,
                fromDocumentId,
                toDocumentId,
                totalSales,
                totalReturns,
                discountsGranted,
                taxableTotal,
                totalTax,
                grandTotal
            );
        }
    }
}