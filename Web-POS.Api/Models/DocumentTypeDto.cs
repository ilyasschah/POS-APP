namespace Api.Models
{
    public class DocumentTypeDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public int DocumentCategoryId { get; set; }
        public int WarehouseId { get; set; }
        public int StockDirection { get; set; }
        public int EditorType { get; set; }
        public string? PrintTemplate { get; set; }
        public int PriceType { get; set; }
        public string? LanguageKey { get; set; }

        // Flattened props from navs
        public string DocumentCategoryName { get; set; } = string.Empty;
        public string WarehouseName { get; set; } = string.Empty;
    }

    public class CreateDocumentTypeRequest
    {
        public required string Name { get; set; }
        public required string Code { get; set; }
        public required int DocumentCategoryId { get; set; }
        public required int WarehouseId { get; set; }
        public int StockDirection { get; set; } = 0;
        public int EditorType { get; set; } = 0;
        public string? PrintTemplate { get; set; }
        public int PriceType { get; set; } = 0;
        public string? LanguageKey { get; set; }
    }

    public class UpdateDocumentTypeRequest
    {
        public required string Name { get; set; }
        public required string Code { get; set; }
        public required int DocumentCategoryId { get; set; }
        public required int WarehouseId { get; set; }
        public int StockDirection { get; set; }
        public int EditorType { get; set; }
        public string? PrintTemplate { get; set; }
        public int PriceType { get; set; }
        public string? LanguageKey { get; set; }
    }
}
