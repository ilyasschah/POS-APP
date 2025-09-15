namespace Products.Api.Models
{
    public class ProductGroupDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = default!;
        public int? ParentGroupId { get; set; }
        public string Color { get; set; } = "Transparent";
        public byte[]? Image { get; set; }
        public int Rank { get; set; } = 0;
    }

    public class CreateProductGroupRequest
    {
        public required string Name { get; set; }
        public int? ParentGroupId { get; set; }
        public string? Color { get; set; }              // default "Transparent" if null/empty
        public string? ImageBase64 { get; set; }        // optional for uploads via query
        public int? Rank { get; set; }                  // default 0 if null
    }

    public class UpdateProductGroupRequest
    {
        public required string Name { get; set; }
        public int? ParentGroupId { get; set; }
        public required string Color { get; set; }
        public string? ImageBase64 { get; set; }
        public required int Rank { get; set; }
    }
}
