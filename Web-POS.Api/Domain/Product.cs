using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Reflection;

namespace Api.Domain
{
    [Table("Product")]
    public class Product
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }

        [ForeignKey(nameof(ProductGroup))]
        public int? ProductGroupId { get; set; }

        [Required, MaxLength(255)]
        public string Name { get; set; } = default!;

        [MaxLength(100)]
        public string? Code { get; set; }

        public int? PLU { get; set; }

        [MaxLength(50)]
        public string? MeasurementUnit { get; set; }

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
            int? rank)
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
            int? rank)
            => new(
                productGroupId, name, code, plu, measurementUnit, price, isTaxInclusivePrice, currencyId,
                isPriceChangeAllowed, isService, isUsingDefaultQuantity, isEnabled, description, dateCreated,
                dateUpdated, cost, markup, image, color, ageRestriction, lastPurchasePrice, rank
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
            int? rank)
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
        }
    }
}
