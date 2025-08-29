using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Product")]
    public class Product
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; }
        public string? Code { get; set; }
        public int? PLU { get; set; }
        public string? MeasurementUnit { get; set; }
        public decimal Price { get; set; }
        public bool IsTaxInclusivePrice { get; set; }
        public bool IsPriceChangeAllowed { get; set; }
        public bool IsService { get; set; }
        public bool IsUsingDefaultQuantity { get; set; }
        public bool IsEnabled { get; set; } = true;
        [StringLength(500)]
        public string? Description { get; set; }
        public decimal Cost { get; set; }
        public decimal? Markup { get; set; }
        public byte[]? Image { get; set; } 
        [StringLength(50)]
        public string Color { get; set; } 
        [StringLength(100)]
        public int? AgeRestriction { get; set; }
        public decimal? LastPurchasePrice { get; set; }
        public int? Rank { get; set; }

        //////////////////////////////////////////////
        public int? ProductGroupId { get; set; }
        [ForeignKey(nameof(ProductGroupId))]
        public virtual ProductGroup ProductGroup { get; set; }
        public int? CurrencyId { get; set; }
        [ForeignKey(nameof(CurrencyId))]
        public virtual Currency Currency { get; set; }
        public DateTime DateCreated { get; set; }
        public DateTime DateUpdated { get; set; }

        private Product(
            string name,
            string? code,
            int? plu,
            string? measurementunit,
            decimal price,
            bool istaxinclusiveprice,
            bool ispricechangeallowed,
            bool isservice,
            bool isusingdefaultquantitu,
            bool isenabled,
            string? description,
            decimal cost,
            decimal? markup,
            byte[]? image,
            string color,
            int? agerestriction,
            decimal? lastpurchaseprice,
            int? rank,
            int? productGroupId,
            int? currencyId
            )
        {
                Name = name;
                Code = code;
                PLU = plu;
                MeasurementUnit = measurementunit;
                Price = price;
                IsTaxInclusivePrice = true;
                IsPriceChangeAllowed = true;
                IsService = false;
                IsUsingDefaultQuantity = true;
                IsEnabled = true;
                Description = description;
                Cost = cost;
                Markup = markup;
                Color = color;
                AgeRestriction = agerestriction;
                LastPurchasePrice = lastpurchaseprice;
                Rank = rank;
                ProductGroupId = productGroupId;
                CurrencyId = currencyId;
                DateCreated = DateTime.UtcNow;
                DateUpdated = DateTime.UtcNow;
        }
        public Product() { }

        public static Product Create(
            string name,
            string? code,
            int? plu,
            string? measurementunit,
            decimal price,
            bool istaxinclusiveprice,
            bool ispricechangeallowed,
            bool isservice,
            bool isusingdefaultquantity,
            bool isenabled,
            string? description,
            decimal cost,
            decimal? markup,
            byte[]? image,
            string color,
            int? agerestriction,
            decimal? lastpurchaseprice,
            int? rank,
            int? productGroupId,
            int? currencyId,
            DateTime? datecreated,
            DateTime? dateupdated
            )
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Product name cannot be null or empty.", nameof(name));

            if (price < 0)
                throw new ArgumentException("Product price cannot be negative.", nameof(price));

            if (productGroupId <= 0)
                throw new ArgumentException("ProductGroupId must be greater than zero.", nameof(productGroupId));

            if (currencyId <= 0)
                throw new ArgumentException("CurrencyId must be greater than zero.", nameof(currencyId));

            return new Product(name, code, plu, measurementunit, price, istaxinclusiveprice, ispricechangeallowed, isservice
                , isusingdefaultquantity, isenabled, description, cost, markup, image, color, agerestriction
                , lastpurchaseprice, rank,
                productGroupId, currencyId
                );
        }

        // Update methods
        public void UpdatePrice(decimal newPrice)
        {
            if (newPrice < 0)
                throw new ArgumentException("Price cannot be negative.", nameof(newPrice));

            Price = newPrice;
            DateUpdated = DateTime.UtcNow;
        }

        public void UpdateName(string newName)
        {
            if (string.IsNullOrWhiteSpace(newName))
                throw new ArgumentException("Name cannot be null or empty.", nameof(newName));

            Name = newName;
            DateUpdated = DateTime.UtcNow;
        }

        public void Disable()
        {
            IsEnabled = false;
            DateUpdated = DateTime.UtcNow;
        }

        public void Enable()
        {
            IsEnabled = true;
            DateUpdated = DateTime.UtcNow;
        }

    }
}