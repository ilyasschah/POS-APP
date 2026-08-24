using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// Links a product to a <see cref="ModifierGroup"/> it offers.
    /// </summary>
    /// <remarks>
    /// A join row rather than a bare many-to-many so it can carry
    /// <see cref="Rank"/>: the order groups appear in the cashier's sheet is a
    /// per-product decision ("Doneness" first on a steak, "Sauce" first on
    /// fries), and a shared group cannot hold one ordering for everybody.
    ///
    /// It is also the row the sync pulls — a till decides whether tapping a
    /// product opens the customise sheet by asking whether any of these exist
    /// for it, so this table has to be present offline like the rest of the
    /// catalogue.
    /// </remarks>
    [Table("ProductModifierGroup")]
    public class ProductModifierGroup : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [ForeignKey(nameof(Product))]
        public int ProductId { get; private set; }

        [ForeignKey(nameof(ModifierGroup))]
        public int ModifierGroupId { get; private set; }

        /// <summary>Ascending order of this group within this product's sheet.</summary>
        public int Rank { get; private set; }

        public DateTime LastModified { get; set; } = DateTime.UtcNow;

        public virtual Product? Product { get; private set; }
        public virtual ModifierGroup? ModifierGroup { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        public ProductModifierGroup() { }

        public static ProductModifierGroup Create(int companyId, int productId,
                                                  int modifierGroupId, int rank = 0)
        {
            if (companyId <= 0) throw new ArgumentException("CompanyId must be valid.", nameof(companyId));
            if (productId <= 0) throw new ArgumentException("ProductId must be valid.", nameof(productId));
            if (modifierGroupId <= 0) throw new ArgumentException("ModifierGroupId must be valid.", nameof(modifierGroupId));

            return new ProductModifierGroup
            {
                CompanyId = companyId,
                ProductId = productId,
                ModifierGroupId = modifierGroupId,
                Rank = rank
            };
        }

        public void UpdateRank(int rank) => Rank = rank;
    }
}
