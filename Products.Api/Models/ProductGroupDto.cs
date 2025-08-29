namespace Products.Api.Models
{
    public class ProductGroupDto
    {
        public string? Name { get; set; }
        public string? Color { get; set; }
        public byte[]? Image { get; set; }
        public int? Rank { get; set; }
        public string? ParentGroupName { get; set; }
        public List<string> ChildGroupNames { get; set; } = new List<string>();
    }
    public class CreateProductGroupRequest
    {
        public required string Name { get; set; }
        public string Color { get; set; }
        public byte[]? Image { get; set; }
        public int Rank { get; set; }
        public int? ParentGroupId { get; set; }
    }
    public class UpdateProductGroupDto
    {
        public required string Name { get; set; }
        public string? Color { get; set; }
        public byte[]? Image { get; set; }
        public int Rank { get; set; }
        public int? ParentGroupId { get; set; }
        public ProductGroupDto? ParentGroup { get; set; }
    }
}