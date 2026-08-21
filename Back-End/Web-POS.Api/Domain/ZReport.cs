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

        /// <summary>
        /// 🚨 LEGACY BOUNDARY, kept for the reports already written against it.
        /// It bounded a period as a company-wide document-id RANGE, which is
        /// broken with more than one register: device B's documents fall inside
        /// device A's range and get swept into A's report, and the second report
        /// of the evening gets a range already consumed. <see cref="SessionId"/>
        /// is the boundary now — see <c>ZReportService</c>.
        /// </summary>
        public int FromDocumentId { get; private set; }
        public int ToDocumentId { get; private set; }

        /// <summary>
        /// The session this report covers. THE boundary: sales, payments and
        /// cash movements are selected by it, so two registers closing the same
        /// evening can never contaminate each other's figures.
        /// Nullable only for reports written before sessions existed.
        /// </summary>
        public int? SessionId { get; private set; }

        /// <summary>The register this report belongs to.</summary>
        public int? PosDeviceId { get; private set; }

        /// <summary>
        /// Human-facing number, per DEVICE: `POS1/00085`.
        ///
        /// 🚨 <see cref="Number"/> is a company-wide sequence, so two registers
        /// closing at the same moment race for the same value — on a fiscal
        /// document. Per-device numbering removes the race by construction
        /// rather than defending against it, and matches how this app already
        /// numbers documents (`POS1-200-000014`).
        /// </summary>
        [MaxLength(32)]
        public string? DisplayNumber { get; private set; }

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

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCashIn { get; private set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCashOut { get; private set; }

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
            decimal grandTotal,
            decimal totalCashIn,
            decimal totalCashOut)
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
            TotalCashIn = totalCashIn;
            TotalCashOut = totalCashOut;
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
            decimal grandTotal,
            decimal totalCashIn = 0,
            decimal totalCashOut = 0,
            int? sessionId = null,
            int? posDeviceId = null,
            string? displayNumber = null)
        {
            if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
            if (number <= 0) throw new ArgumentException("Invalid Report Number");
            // A SESSION-bounded report has no meaningful document range — the
            // session is the boundary — so the range is only validated when it
            // is actually being used.
            if (sessionId is null &&
                (fromDocumentId <= 0 || toDocumentId <= 0 || fromDocumentId > toDocumentId))
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
                grandTotal,
                totalCashIn,
                totalCashOut
            )
            {
                SessionId = sessionId,
                PosDeviceId = posDeviceId,
                DisplayNumber = displayNumber,
            };
        }

        /// <summary>Next per-device number, formatted `POS1/00085`.</summary>
        public static string FormatDisplayNumber(string? deviceName, int sequence)
        {
            var prefix = string.IsNullOrWhiteSpace(deviceName) ? "POS" : deviceName.Trim();
            return $"{prefix}/{sequence:D5}";
        }
    }
}