using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// One applied discount on a sale, normalized so every source is recorded
    /// discretely instead of being squeezed into the Document/DocumentItem
    /// `Discount` column. Percentages are never summed: each row keeps its own
    /// <see cref="Value"/> + <see cref="ValueType"/>; only <see cref="Amount"/>
    /// (resolved currency) is additive. Mirrors the client `discount_lines` table.
    /// </summary>
    [Table("DiscountLine")]
    public class DiscountLine
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public int DocumentId { get; private set; }

        /// Set for an item-level discount (manual item / promotion); null for a
        /// whole-order discount (manual cart / customer profile / loyalty points).
        public int? ProductId { get; private set; }

        /// One of: manual_item, manual_cart, promotion, customer_profile,
        /// loyalty_points.
        public string Source { get; private set; } = string.Empty;

        /// promotionId / customerId / loyaltyCardId — for traceability.
        public int? SourceRefId { get; private set; }

        /// Configured value as entered (e.g. 10) and its type: 0 = %, 1 = fixed.
        public decimal Value { get; private set; }
        public int ValueType { get; private set; }

        /// The resolved money actually deducted, in company currency. The only
        /// field that may be summed across rows.
        public decimal Amount { get; private set; }

        /// Application order, so the stacking can be replayed exactly.
        public int Sequence { get; private set; }

        /// Optional display label (promo name, "Loyalty points", …).
        public string? Label { get; private set; }

        public DateTime DateCreated { get; private set; }

        [ForeignKey(nameof(DocumentId))]
        public virtual Document? Document { get; private set; }

        private DiscountLine(
            int companyId, int documentId, int? productId, string source,
            int? sourceRefId, decimal value, int valueType, decimal amount,
            int sequence, string? label)
        {
            CompanyId = companyId;
            DocumentId = documentId;
            ProductId = productId;
            Source = source;
            SourceRefId = sourceRefId;
            Value = value;
            ValueType = valueType;
            Amount = amount;
            Sequence = sequence;
            Label = label;
            DateCreated = DateTime.UtcNow;
        }

        public DiscountLine() { }

        public static DiscountLine Create(
            int companyId, int documentId, int? productId, string source,
            int? sourceRefId, decimal value, int valueType, decimal amount,
            int sequence, string? label)
            => new DiscountLine(
                companyId, documentId, productId, source, sourceRefId,
                value, valueType, amount, sequence, label);
    }
}
