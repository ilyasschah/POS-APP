using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Reflection;

namespace Api.Domain
{
    [Table("Product")]
    public class Product : ISyncableEntity
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public DateTime LastModified { get; set; } = DateTime.UtcNow;

        [ForeignKey(nameof(ProductGroup))]
        public int? ProductGroupId { get; set; }

        [Required, MaxLength(255)]
        public string Name { get; set; } = default!;

        [MaxLength(100)]
        public string? Code { get; set; }

        public int? PLU { get; set; }

        /// <summary>
        /// Legacy free-text unit. Superseded by <see cref="UomId"/> and kept only
        /// so receipts, document lines and exports written against it keep
        /// working; new code must read the unit through
        /// <c>UnitOfMeasure.Get(UomId)</c>.
        /// </summary>
        [MaxLength(50)]
        public string? MeasurementUnit { get; set; }

        /// <summary>
        /// Id into the hardcoded <see cref="UnitOfMeasure"/> catalog. Defaults to
        /// pieces, which converts 1:1 and therefore cannot disturb existing stock.
        /// </summary>
        public int UomId { get; set; } = UnitOfMeasure.PiecesId;

        /// <summary>
        /// How many reference units (pieces) are in one box or one pack of THIS
        /// product — 24 for a 24-can box.
        /// </summary>
        /// <remarks>
        /// Only read for the pack-sized units (see
        /// <see cref="UnitOfMeasure.IsPackSized"/>); a kilogram is 1000 g whatever
        /// the product, so the column is ignored everywhere else.
        ///
        /// NULL means "use the nominal 12 / 6 from the catalog", which is exactly how
        /// every product behaved before this column existed — so adding it moved no
        /// existing stock figure. Stock is held in pieces either way, so changing a
        /// product's pack size never rewrites its stock: it changes how many boxes
        /// the pieces already on hand add up to.
        /// </remarks>
        /// <remarks>
        /// Precision is set in <c>AppDbContext.OnModelCreating</c>, not here: a
        /// <c>[Precision]</c> attribute LOSES to the model-wide decimal(18,2)
        /// convention in <c>ConfigureConventions</c>, and a pack size is a count of
        /// pieces — decimal(18,4), like every other quantity column.
        /// </remarks>
        public decimal? PackSize { get; set; }

        /// <summary>
        /// Sold by weight. At the POS this makes the product ask for a quantity
        /// (from the scale, or from the keypad when no scale is attached) instead
        /// of adding a single unit, and turns the Price button into a quantity
        /// editor. Stock is still deducted in the category's reference unit.
        /// </summary>
        public bool IsToWeigh { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Price { get; set; }  // default 0

        public bool IsTaxInclusivePrice { get; set; } // default 1

        [ForeignKey(nameof(Currency))]
        public int? CurrencyId { get; set; }

        public bool IsPriceChangeAllowed { get; set; }   // default 0
        public bool IsService { get; set; }              // default 0
        public bool IsUsingDefaultQuantity { get; set; } // default 1
        public bool IsEnabled { get; set; }              // default 1
        public string? Description { get; set; }

        public DateTime? DateCreated { get; set; }
        public DateTime? DateUpdated { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Cost { get; set; } // default 0

        [Column(TypeName = "decimal(18,2)")]
        public decimal? Markup { get; set; } // default 0

        public byte[]? Image { get; set; }

        [MaxLength(50)]
        public string Color { get; set; } = "Transparent"; // default

        public int? AgeRestriction { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? LastPurchasePrice { get; set; } // default 0

        public int? Rank { get; set; } // default 0

        // Navs
        public ProductGroup? ProductGroup { get; set; }
        public Currency? Currency { get; set; }
        public virtual ICollection<ProductTax> ProductTaxes { get; set; } = new List<ProductTax>();
        public virtual ICollection<Barcode> Barcodes { get; set; } = new List<Barcode>();
        public Product() { }

        private Product(
            int? productGroupId,
            string name,
            string? code,
            int? plu,
            string? measurementUnit,
            decimal price,
            bool isTaxInclusivePrice,
            int? currencyId,
            bool isPriceChangeAllowed,
            bool isService,
            bool isUsingDefaultQuantity,
            bool isEnabled,
            string? description,
            DateTime? dateCreated,
            DateTime? dateUpdated,
            decimal cost,
            decimal? markup,
            byte[]? image,
            string color,
            int? ageRestriction,
            decimal? lastPurchasePrice,
            int? rank,
            int uomId,
            bool isToWeigh,
            decimal? packSize)
        {
            ProductGroupId = productGroupId;
            Name = name;
            Code = code;
            PLU = plu;
            MeasurementUnit = measurementUnit;
            Price = price;
            IsTaxInclusivePrice = isTaxInclusivePrice;
            CurrencyId = currencyId;
            IsPriceChangeAllowed = isPriceChangeAllowed;
            IsService = isService;
            IsUsingDefaultQuantity = isUsingDefaultQuantity;
            IsEnabled = isEnabled;
            Description = description;
            DateCreated = dateCreated;
            DateUpdated = dateUpdated;
            Cost = cost;
            Markup = markup;
            Image = image;
            Color = color;
            AgeRestriction = ageRestriction;
            LastPurchasePrice = lastPurchasePrice;
            Rank = rank;
            UomId = uomId;
            IsToWeigh = isToWeigh;
            PackSize = packSize;
        }

        public static Product Create(
            int? productGroupId,
            string name,
            string? code,
            int? plu,
            string? measurementUnit,
            decimal price,
            bool isTaxInclusivePrice,
            int? currencyId,
            bool isPriceChangeAllowed,
            bool isService,
            bool isUsingDefaultQuantity,
            bool isEnabled,
            string? description,
            DateTime? dateCreated,
            DateTime? dateUpdated,
            decimal cost,
            decimal? markup,
            byte[]? image,
            string color,
            int? ageRestriction,
            decimal? lastPurchasePrice,
            int? rank,
            int uomId,
            bool isToWeigh,
            decimal? packSize)
            => new(
                productGroupId, name, code, plu, measurementUnit, price, isTaxInclusivePrice, currencyId,
                isPriceChangeAllowed, isService, isUsingDefaultQuantity, isEnabled, description, dateCreated,
                dateUpdated, cost, markup, image, color, ageRestriction, lastPurchasePrice, rank,
                uomId, isToWeigh, packSize
            );

        public void Update(
            int? productGroupId,
            string name,
            string? code,
            int? plu,
            string? measurementUnit,
            decimal price,
            bool isTaxInclusivePrice,
            int? currencyId,
            bool isPriceChangeAllowed,
            bool isService,
            bool isUsingDefaultQuantity,
            bool isEnabled,
            string? description,
            DateTime? dateUpdated,
            decimal cost,
            decimal? markup,
            byte[]? image,
            string color,
            int? ageRestriction,
            decimal? lastPurchasePrice,
            int? rank,
            int uomId,
            bool isToWeigh,
            decimal? packSize)
        {
            ProductGroupId = productGroupId;
            Name = name;
            Code = code;
            PLU = plu;
            MeasurementUnit = measurementUnit;
            Price = price;
            IsTaxInclusivePrice = isTaxInclusivePrice;
            CurrencyId = currencyId;
            IsPriceChangeAllowed = isPriceChangeAllowed;
            IsService = isService;
            IsUsingDefaultQuantity = isUsingDefaultQuantity;
            IsEnabled = isEnabled;
            Description = description;
            DateUpdated = dateUpdated;
            Cost = cost;
            Markup = markup;
            Image = image;
            Color = color;
            AgeRestriction = ageRestriction;
            LastPurchasePrice = lastPurchasePrice;
            Rank = rank;
            UomId = uomId;
            IsToWeigh = isToWeigh;
            PackSize = packSize;
        }
    }
}
