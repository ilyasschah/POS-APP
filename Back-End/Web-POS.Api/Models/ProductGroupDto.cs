namespace Api.Models
{
    public class ProductGroupDto
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string Name { get; set; } = string.Empty;
        public int? ParentGroupId { get; set; }
        public string? ParentGroupName { get; set; }
        public string Color { get; set; } = "Transparent";
        public byte[]? Image { get; set; }
        public int Rank { get; set; }
    }

    public class CreateProductGroupRequest
    {
        public required string Name { get; set; }
        public int? ParentGroupId { get; set; }
        public string? Color { get; set; }
        public byte[]? Image { get; set; }
        public int Rank { get; set; }
    }

    public class UpdateProductGroupRequest
    {
        public required int Id { get; set; }
        public string? Name { get; set; }
        public int? ParentGroupId { get; set; }
        public string? Color { get; set; }
        public byte[]? Image { get; set; }
        public int? Rank { get; set; }
    }
}