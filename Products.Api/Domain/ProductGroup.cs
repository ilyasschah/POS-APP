using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace Products.Api.Domain
{
    [Table("ProductGroup")] 
    public class ProductGroup
    {
        [Key]
        public int Id { get; set; }
        [Required]
        public string Name { get; set; }
        public int? ParentGroupId { get; set; }
        [Required]
        public string Color { get; set; }
        public byte[]? Image { get; set; }
        public int Rank { get; set; }
        [ForeignKey("ParentGroupId")]
        public virtual ProductGroup? ParentGroup { get; set; }
        public virtual ICollection<ProductGroup> ChildGroups { get; set; } = new HashSet<ProductGroup>();
        
        private ProductGroup(string name, int? parentgroupid, string color,byte[]? image ,int rank )
        {
            Name = name;
            ParentGroupId = parentgroupid;
            Color = color;
            Image = image;
            Rank = rank;
        }
        public ProductGroup() { }
        public static ProductGroup Create(string name, int? parentgroupid, string color,byte[]? image, int rank)
        {
            if (name == null)
            {
                throw new ArgumentException("Please chouse a name .", nameof(name));
            }
            return new ProductGroup(name, parentgroupid, color, image,rank);
        }
        public void Update(string newName, int parentgroupid, string color, byte[] image, int rank)
        {
            if (string.IsNullOrWhiteSpace(newName))
            {
                throw new ArgumentException("Name cannot be null or whitespace.", nameof(newName));
            }
            Name = newName;
            ParentGroupId = parentgroupid;
            Color = color;
            Rank = rank;
            Image = image;
        }
    }
}
