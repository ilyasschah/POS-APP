using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentType")]
    public class DocumentType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(255)]
        public string Name { get; private set; }

        [Required]
        [MaxLength(50)]
        public string Code { get; private set; }

        [ForeignKey(nameof(DocumentCategory))]
        public int DocumentCategoryId { get; private set; }
        public virtual DocumentCategory DocumentCategory { get; private set; }

        [ForeignKey(nameof(Warehouse))]
        public int WarehouseId { get; private set; }
        public virtual Warehouse Warehouse { get; private set; }

        public int StockDirection { get; private set; } = 0;

        public int EditorType { get; private set; } = 0;

        public string? PrintTemplate { get; private set; }

        public int PriceType { get; private set; } = 0;

        [MaxLength(100)]
        public string? LanguageKey { get; private set; }

        public DocumentType() { }

        private DocumentType(
            string name,
            string code,
            int documentCategoryId,
            int warehouseId,
            int stockDirection,
            int editorType,
            string? printTemplate,
            int priceType,
            string? languageKey)
        {
            Name = name;
            Code = code;
            DocumentCategoryId = documentCategoryId;
            WarehouseId = warehouseId;
            StockDirection = stockDirection;
            EditorType = editorType;
            PrintTemplate = printTemplate;
            PriceType = priceType;
            LanguageKey = languageKey;
        }

        public static DocumentType Create(
            string name,
            string code,
            int documentCategoryId,
            int warehouseId,
            int stockDirection = 0,
            int editorType = 0,
            string? printTemplate = null,
            int priceType = 0,
            string? languageKey = null)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name is required.", nameof(name));

            if (string.IsNullOrWhiteSpace(code))
                throw new ArgumentException("Code is required.", nameof(code));

            if (documentCategoryId <= 0)
                throw new ArgumentException("DocumentCategoryId must be greater than zero.", nameof(documentCategoryId));

            if (warehouseId <= 0)
                throw new ArgumentException("WarehouseId must be greater than zero.", nameof(warehouseId));

            return new DocumentType(
                name,
                code,
                documentCategoryId,
                warehouseId,
                stockDirection,
                editorType,
                printTemplate,
                priceType,
                languageKey
            );
        }

        //public void Update(
        //    string name,
        //    string code,
        //    int documentCategoryId,
        //    int warehouseId,
        //    int stockDirection,
        //    int editorType,
        //    string? printTemplate,
        //    int priceType,
        //    string? languageKey)
        //{
        //    if (string.IsNullOrWhiteSpace(name))
        //        throw new ArgumentException("Name is required.", nameof(name));
        //    if (string.IsNullOrWhiteSpace(code))
        //        throw new ArgumentException("Code is required.", nameof(code));
        //    if (documentCategoryId <= 0)
        //        throw new ArgumentException("DocumentCategoryId must be greater than zero.", nameof(documentCategoryId));
        //    if (warehouseId <= 0)
        //        throw new ArgumentException("WarehouseId must be greater than zero.", nameof(warehouseId));
        //    Name = name;
        //    Code = code;
        //    DocumentCategoryId = documentCategoryId;
        //    WarehouseId = warehouseId;
        //    StockDirection = stockDirection;
        //    EditorType = editorType;
        //    PrintTemplate = printTemplate;
        //    PriceType = priceType;
        //    LanguageKey = languageKey;
        //}
    }
}
