using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// One modifier option as sold on one banked document line — the permanent
    /// half of <see cref="PosOrderItemModifier"/>.
    /// </summary>
    /// <remarks>
    /// Both exist for the same reason <c>PosOrderItemTax</c> and
    /// <c>DocumentItemTax</c> both exist: an open order is working state that
    /// gets deleted when it is paid or voided, while a Document is the record
    /// the shop is audited against. A receipt reprinted a year later reads from
    /// THIS table, so the snapshot rule matters more here than anywhere —
    /// see the remarks on <see cref="PosOrderItemModifier"/>.
    ///
    /// This is also the table every "what sells with what" report will read.
    /// It is the reason modifiers are child rows rather than a JSON blob on the
    /// line: <c>GROUP BY ModifierOptionId</c> is a plain query here and an
    /// awkward one against JSON.
    /// </remarks>
    [Table("DocumentItemModifier")]
    public class DocumentItemModifier
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(DocumentItem))]
        public int DocumentItemId { get; private set; }

        /// <summary>
        /// The catalogue option this came from, for reporting. Null once that
        /// option is deleted; the snapshot below still tells the whole story.
        /// </summary>
        public int? ModifierOptionId { get; private set; }

        /// <summary>Group name as it read at the time of sale.</summary>
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

        public virtual DocumentItem? DocumentItem { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public DocumentItemModifier() { }

        public static DocumentItemModifier Create(int companyId, int documentItemId,
                                                  int? modifierOptionId, string name,
                                                  decimal additionalPrice,
                                                  string? groupName = null, int rank = 0)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (documentItemId <= 0) throw new ArgumentException("DocumentItemId must be valid.", nameof(documentItemId));
            if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Modifier name cannot be empty.", nameof(name));

            return new DocumentItemModifier
            {
                CompanyId = companyId,
                DocumentItemId = documentItemId,
                ModifierOptionId = modifierOptionId,
                GroupName = string.IsNullOrWhiteSpace(groupName) ? null : groupName.Trim(),
                Name = name.Trim(),
                AdditionalPrice = additionalPrice,
                Rank = rank
            };
        }
    }
}
