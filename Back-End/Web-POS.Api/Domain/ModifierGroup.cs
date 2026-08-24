using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// A named set of choices a cashier picks from when selling a product —
    /// "Toppings", "Doneness", "Select Sauce".
    /// </summary>
    /// <remarks>
    /// A group is company-level and shared: "Toppings" is defined once and
    /// linked to every burger through <see cref="ProductModifierGroup"/>. That
    /// is the whole reason this is not a column on Product — the alternative
    /// was re-typing the same six toppings on forty products and having them
    /// drift apart.
    ///
    /// <see cref="MinSelections"/> and <see cref="MaxSelections"/> together
    /// describe every selection rule the POS needs:
    /// <list type="bullet">
    ///   <item>0/1 — optional, pick at most one (radio, clearable)</item>
    ///   <item>1/1 — mandatory, exactly one (radio, forced)</item>
    ///   <item>0/N — optional, pick several (checkboxes)</item>
    ///   <item>2/4 — pick between two and four</item>
    /// </list>
    /// The POS blocks "Add to order" until every linked group is satisfied, so
    /// a mandatory group is a genuine gate on the sale, not a hint.
    /// </remarks>
    [Table("ModifierGroup")]
    public class ModifierGroup : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [Required, MaxLength(100)]
        public string Name { get; private set; } = default!;

        /// <summary>
        /// Fewest options that must be chosen. 0 makes the group optional;
        /// anything higher makes it a gate on adding the item to the cart.
        /// </summary>
        public int MinSelections { get; private set; }

        /// <summary>
        /// Most options that may be chosen. 1 renders as a radio list, more than
        /// 1 as checkboxes — which is the only thing that decides the control
        /// the cashier sees.
        /// </summary>
        public int MaxSelections { get; private set; } = 1;

        /// <summary>
        /// Whether this group accepts a free-text note alongside its options.
        /// </summary>
        /// <remarks>
        /// This is what keeps "no ice", "allergic to nuts" possible once the old
        /// free-text ProductComment catalogue is retired. The note is written to
        /// the order line's existing <c>Comment</c> column — it is a property of
        /// a group, not a second parallel feature, and nothing downstream needed
        /// a new column to carry it.
        /// </remarks>
        public bool AllowsFreeText { get; private set; }

        /// <summary>Ascending display order within a product's sheet.</summary>
        public int Rank { get; private set; }

        public bool IsEnabled { get; private set; } = true;

        public DateTime LastModified { get; set; } = DateTime.UtcNow;

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public virtual ICollection<ModifierOption> Options { get; private set; }
            = new List<ModifierOption>();

        public ModifierGroup() { }

        private ModifierGroup(int companyId, string name, int minSelections, int maxSelections,
                              bool allowsFreeText, int rank, bool isEnabled)
        {
            CompanyId = companyId;
            Name = name;
            MinSelections = minSelections;
            MaxSelections = maxSelections;
            AllowsFreeText = allowsFreeText;
            Rank = rank;
            IsEnabled = isEnabled;
        }

        public static ModifierGroup Create(int companyId, string name, int minSelections = 0,
                                           int maxSelections = 1, bool allowsFreeText = false,
                                           int rank = 0, bool isEnabled = true)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Group name cannot be empty.", nameof(name));

            var (min, max) = Normalise(minSelections, maxSelections);
            return new ModifierGroup(companyId, name.Trim(), min, max, allowsFreeText, rank, isEnabled);
        }

        public void Update(string? name, int? minSelections, int? maxSelections,
                           bool? allowsFreeText, int? rank, bool? isEnabled)
        {
            if (!string.IsNullOrWhiteSpace(name)) Name = name.Trim();
            if (allowsFreeText.HasValue) AllowsFreeText = allowsFreeText.Value;
            if (rank.HasValue) Rank = rank.Value;
            if (isEnabled.HasValue) IsEnabled = isEnabled.Value;

            // Re-normalised TOGETHER even when only one arrives, because the pair
            // has to stay consistent: raising Min above the stored Max would
            // otherwise leave a group nothing can ever satisfy, and the POS would
            // refuse to sell the product with no way to explain why.
            if (minSelections.HasValue || maxSelections.HasValue)
            {
                var (min, max) = Normalise(minSelections ?? MinSelections,
                                           maxSelections ?? MaxSelections);
                MinSelections = min;
                MaxSelections = max;
            }
        }

        /// <summary>
        /// Forces the pair into a range that can actually be satisfied.
        /// </summary>
        /// <remarks>
        /// Clamped rather than rejected. These arrive from an admin form and from
        /// sync, and a group that throws on save is worse than one that quietly
        /// makes sense: the failure would surface at the till, mid-sale, as a
        /// product that cannot be added.
        /// </remarks>
        private static (int Min, int Max) Normalise(int min, int max)
        {
            if (min < 0) min = 0;
            if (max < 1) max = 1;
            if (max < min) max = min;
            return (min, max);
        }
    }
}
