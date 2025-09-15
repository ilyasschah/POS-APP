using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ProductGroup")]
    public class ProductGroup
    {
        [Key]
        public int Id { get; set; }

        [Required, MaxLength(255)]
        public string Name { get; set; } = default!;

        [ForeignKey(nameof(ParentGroup))]
        public int? ParentGroupId { get; set; }

        [Required, MaxLength(50)]
        public string Color { get; set; } = "Transparent"; // DB default

        public byte[]? Image { get; set; }

        public int Rank { get; set; } = 0; // DB default

        // Navigation (self-reference)
        public ProductGroup? ParentGroup { get; set; }
        public ICollection<ProductGroup> Children { get; set; } = new List<ProductGroup>();

        public ProductGroup() { }

        private ProductGroup(string name, int? parentGroupId, string color, byte[]? image, int rank)
        {
            Name = name;
            ParentGroupId = parentGroupId;
            Color = string.IsNullOrWhiteSpace(color) ? "Transparent" : color;
            Image = image;
            Rank = rank;
        }

        public static ProductGroup Create(string name, int? parentGroupId = null, string color = "Transparent", byte[]? image = null, int rank = 0)
            => new(name, parentGroupId, color, image, rank);

        public void Update(string name, int? parentGroupId, string color, byte[]? image, int rank)
        {
            Name = name;
            ParentGroupId = parentGroupId;
            Color = string.IsNullOrWhiteSpace(color) ? "Transparent" : color;
            Image = image;
            Rank = rank;
        }
    }
}
