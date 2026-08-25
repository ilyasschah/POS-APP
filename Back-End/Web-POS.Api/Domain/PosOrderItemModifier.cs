using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// One modifier option as chosen on one open-order line.
    /// </summary>
    /// <remarks>
    /// 🚨 <b>A snapshot, not a reference.</b> <see cref="Name"/> and
    /// <see cref="AdditionalPrice"/> are COPIED off the option at the moment of
    /// sale and never read back from the catalogue afterwards. Renaming "Extra
    /// Cheese" to "Double Cheese", repricing it from 10 to 12, or deleting it
    /// entirely must not reach backwards and change what a parked order says it
    /// sold — the same rule <c>CartItem.isTaxInclusive</c> already follows, and
    /// for the same reason.
    ///
    /// <see cref="ModifierOptionId"/> is therefore nullable and carries no
    /// foreign key: it exists so reports can group by option ("how many Extra
    /// Cheese this month"), and a deleted option leaves the line perfectly
    /// readable with a null id and its name and price intact.
    ///
    /// The surcharge is ALSO already inside <c>PosOrderItem.Price</c> — that is
    /// what makes tax, discounts and promotions work with no changes at all.
    /// These rows exist to show the breakdown and to report on it, never to be
    /// re-added to a total. Summing them into a line total would double-charge
    /// every modifier on the receipt.
    /// </remarks>
    [Table("PosOrderItemModifier")]
    public class PosOrderItemModifier
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(PosOrderItem))]
        public int PosOrderItemId { get; private set; }

        /// <summary>
        /// The catalogue option this came from, for reporting. Null once that
        /// option is deleted — the snapshot below still tells the whole story.
        /// </summary>
        public int? ModifierOptionId { get; private set; }

        /// <summary>Group name as it read at the time of sale, for grouped display.</summary>
        [MaxLength(100)]
        public string? GroupName { get; private set; }

        /// <summary>Option name as it read at the time of sale.</summary>
        [Required, MaxLength(100)]
        public string Name { get; private set; } = default!;

        /// <summary>Surcharge as it was priced at the time of sale.</summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal AdditionalPrice { get; private set; }

        /// <summary>Ascending display order, preserving the sheet's ordering.</summary>
        public int Rank { get; private set; }

        public virtual PosOrderItem? PosOrderItem { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public PosOrderItemModifier() { }

        public static PosOrderItemModifier Create(int companyId, int posOrderItemId,
                                                  int? modifierOptionId, string name,
                                                  decimal additionalPrice,
                                                  string? groupName = null, int rank = 0)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (posOrderItemId <= 0) throw new ArgumentException("PosOrderItemId must be valid.", nameof(posOrderItemId));
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Modifier name cannot be empty.", nameof(name));

            return new PosOrderItemModifier
            {
                CompanyId = companyId,
                PosOrderItemId = posOrderItemId,
                ModifierOptionId = modifierOptionId,
                GroupName = string.IsNullOrWhiteSpace(groupName) ? null : groupName.Trim(),
                Name = name.Trim(),
                AdditionalPrice = additionalPrice,
                Rank = rank
            };
        }
    }
}
