using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("PosOrderItem")]
    public class PosOrderItem
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }

        public int PosOrderId { get; private set; }
        public int ProductId { get; private set; }
        public int RoundNumber { get; private set; }
        public decimal Quantity { get; private set; }
        public decimal Price { get; private set; }
        public bool IsLocked { get; private set; }
        public decimal Discount { get; private set; }
        public int DiscountType { get; private set; }
        public bool IsFeatured { get; private set; }
        public int? VoidedBy { get; private set; }
        public string? Comment { get; private set; }
        public DateTime DateCreated { get; private set; }
        public string? Bundle { get; private set; }
        public int DiscountAppliedType { get; private set; }

        /// <summary>
        /// The per-item discount AS THE OPERATOR ENTERED IT — 10 with
        /// <see cref="DiscountInputType"/> 0 meaning "10%" — while
        /// <see cref="Discount"/> holds the resolved per-unit money.
        ///
        /// 🚨 Both are needed, and only for OPEN orders. The POS always calls
        /// `setItemDiscount(..., discountType: 1, inputValue:, inputType:)`, so
        /// <see cref="DiscountType"/> is permanently 1 (fixed) on the wire and
        /// the typed figure lived only in the client's `discount_lines` — a table
        /// that never crosses for an open order (only checkout's BatchSync sends
        /// it). A colleague's order reopened on a second till therefore showed
        /// the flattened money instead of "10%", and re-saving it there recorded
        /// the money as if that were what had been typed.
        ///
        /// Nullable on purpose: rows written before this existed, and any
        /// discount that genuinely WAS entered as a fixed amount, leave it null
        /// and the client falls back to <see cref="Discount"/> exactly as before.
        /// </summary>
        public decimal? DiscountInputValue { get; private set; }

        /// <summary>Type of <see cref="DiscountInputValue"/>: 0 = %, 1 = fixed.</summary>
        public int? DiscountInputType { get; private set; }

        [ForeignKey("PosOrderId")]
        public virtual PosOrder? PosOrder { get; private set; }

        [ForeignKey("ProductId")]
        public virtual Product? Product { get; private set; }

        [ForeignKey("VoidedBy")]
        public virtual User? VoidedByUser { get; private set; }

        public PosOrderItem() { }

        private PosOrderItem(int companyId, int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment, string? bundle, decimal? discountInputValue, int? discountInputType)
        {
            CompanyId = companyId;
            PosOrderId = posOrderId;
            ProductId = productId;
            RoundNumber = roundNumber;
            Quantity = quantity;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            DiscountAppliedType = discountAppliedType;
            Comment = comment;
            Bundle = bundle;
            DiscountInputValue = discountInputValue;
            DiscountInputType = discountInputType;
            DateCreated = DateTime.UtcNow;
            IsLocked = false;
            IsFeatured = false;
            VoidedBy = null;
        }

        public static PosOrderItem Create(int companyId, int posOrderId, int productId, int roundNumber, decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment, string? bundle, decimal? discountInputValue = null, int? discountInputType = null)
        {
            if (companyId <= 0) throw new ArgumentException("Company ID must be valid.", nameof(companyId));
            if (quantity <= 0) throw new ArgumentException("Quantity must be positive.", nameof(quantity));
            if (price < 0) throw new ArgumentException("Price cannot be negative.", nameof(price));

            return new PosOrderItem(companyId, posOrderId, productId, roundNumber, quantity, price, discount, discountType, discountAppliedType, comment, bundle, discountInputValue, discountInputType);
        }

        public void UpdateDetails(decimal quantity, decimal price, decimal discount, int discountType, int discountAppliedType, string? comment, decimal? discountInputValue = null, int? discountInputType = null)
        {
            if (IsLocked)
                throw new InvalidOperationException("This item is locked because it has already been sent to the kitchen. Please void it to make changes."); 
            if (quantity <= 0) throw new ArgumentException("Quantity must be positive.", nameof(quantity));
            if (price < 0) throw new ArgumentException("Price cannot be negative.", nameof(price));

            Quantity = quantity;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            DiscountAppliedType = discountAppliedType;
            Comment = comment;
            DiscountInputValue = discountInputValue;
            DiscountInputType = discountInputType;
        }

        public void LockItem()
        {
            IsLocked = true;
        }

        public void VoidItem(int voidedById)
        {
            VoidedBy = voidedById;
        }
    }
}