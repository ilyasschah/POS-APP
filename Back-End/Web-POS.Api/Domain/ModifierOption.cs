using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// One choice inside a <see cref="ModifierGroup"/> — "Extra Bacon" at
    /// +12.00, "No Sugar" at +0.00.
    /// </summary>
    /// <remarks>
    /// <see cref="AdditionalPrice"/> is added to the product's unit price when
    /// the option is chosen, BEFORE tax and before any discount, so the surcharge
    /// is taxed and discounted exactly like the rest of the line. Zero is an
    /// ordinary value, not an absence: "No Sugar" is a real instruction to the
    /// kitchen that happens to be free.
    ///
    /// The price is `decimal(18,2)` to match Product.Price — a modifier is money
    /// on a receipt and has to round the same way everything beside it does.
    /// </remarks>
    [Table("ModifierOption")]
    public class ModifierOption : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(ModifierGroup))]
        public int ModifierGroupId { get; private set; }

        [Required, MaxLength(100)]
        public string Name { get; private set; } = default!;

        /// <summary>
        /// Added to the item's unit price when chosen. May be 0, and may be
        /// negative — a "small size" discount is a legitimate modifier.
        /// </summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal AdditionalPrice { get; private set; }

        /// <summary>Ascending display order within the group.</summary>
        public int Rank { get; private set; }

        public bool IsEnabled { get; private set; } = true;

        public DateTime LastModified { get; set; } = DateTime.UtcNow;

        public virtual ModifierGroup? ModifierGroup { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public ModifierOption() { }

        private ModifierOption(int companyId, int modifierGroupId, string name,
                               decimal additionalPrice, int rank, bool isEnabled)
        {
            CompanyId = companyId;
            ModifierGroupId = modifierGroupId;
            Name = name;
            AdditionalPrice = additionalPrice;
            Rank = rank;
            IsEnabled = isEnabled;
        }

        public static ModifierOption Create(int companyId, int modifierGroupId, string name,
                                            decimal additionalPrice = 0m, int rank = 0,
                                            bool isEnabled = true)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (modifierGroupId <= 0) throw new ArgumentException("ModifierGroupId must be valid.", nameof(modifierGroupId));
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Option name cannot be empty.", nameof(name));

            return new ModifierOption(companyId, modifierGroupId, name.Trim(), additionalPrice, rank, isEnabled);
        }

        public void Update(string? name, decimal? additionalPrice, int? rank, bool? isEnabled)
        {
            if (!string.IsNullOrWhiteSpace(name)) Name = name.Trim();
            // No IsNullOrWhiteSpace-style guard on the money: 0 is a real price
            // and `additionalPrice.HasValue` is the only correct test for "the
            // caller meant to set this".
            if (additionalPrice.HasValue) AdditionalPrice = additionalPrice.Value;
            if (rank.HasValue) Rank = rank.Value;
            if (isEnabled.HasValue) IsEnabled = isEnabled.Value;
        }
    }
}
