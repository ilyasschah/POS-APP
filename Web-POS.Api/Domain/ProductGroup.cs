using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ProductGroup")]
    public class ProductGroup
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }

        [Required, MaxLength(255)]
        public string Name { get; private set; } = default!;

        public int? ParentGroupId { get; private set; }

        [Required, MaxLength(50)]
        public string Color { get; private set; } = "Transparent";

        public byte[]? Image { get; private set; }

        public int Rank { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        [ForeignKey(nameof(ParentGroupId))]
        public virtual ProductGroup? ParentGroup { get; private set; }

        public virtual ICollection<ProductGroup> Children { get; private set; } = new List<ProductGroup>();

        public ProductGroup() { }

        private ProductGroup(string name, int? parentGroupId, string color, byte[]? image, int rank, int companyId)
        {
            Name = name;
            ParentGroupId = parentGroupId;
            Color = string.IsNullOrWhiteSpace(color) ? "Transparent" : color;
            Image = image;
            Rank = rank;
            CompanyId = companyId;
        }

        public static ProductGroup Create(string name, int? parentGroupId, string color, byte[]? image, int rank, int companyId)
        {
            return new ProductGroup(name, parentGroupId, color, image, rank, companyId);
        }

        public void Update(string name, int? parentGroupId, string color, byte[]? image, int rank, int companyId)
        {
            Name = name;
            ParentGroupId = parentGroupId;
            Color = string.IsNullOrWhiteSpace(color) ? "Transparent" : color;
            Image = image;
            Rank = rank;
            
            if (ParentGroupId == Id)
            {
                ParentGroupId = null;
            }

            if (CompanyId != companyId)
            {
                CompanyId = companyId;
                Company = null;
            }
        }
    }
}