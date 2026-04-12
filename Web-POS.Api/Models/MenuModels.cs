namespace Api.Models
{
    public class MenuTaxDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public bool IsFixed { get; set; }
        public bool IsTaxOnTotal { get; set; }
    }

    public class MenuProductDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public bool IsTaxInclusivePrice { get; set; }
        public string Color { get; set; } = string.Empty;
        public byte[]? Image { get; set; }
        public decimal StockQuantity { get; set; }
        public List<MenuTaxDto> Taxes { get; set; } = new();
    }

    public class MenuCategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;
        public byte[]? Image { get; set; }
        public List<MenuProductDto> Products { get; set; } = new();
    }
}