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

    /// <summary>
    /// One group as an export carries it. Identified by name (unique per company)
    /// and placed by its parent's name, so a file can be re-imported into another
    /// company, where no id means anything.
    /// </summary>
    public class ProductGroupExportDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? ParentGroupName { get; set; }
        public string Color { get; set; } = "Transparent";
        public int Rank { get; set; }
        public int ProductCount { get; set; }
    }

    public class ImportProductGroupRow
    {
        public string Name { get; set; } = string.Empty;

        /// <summary>The parent's name. Null or blank = a root group.</summary>
        public string? ParentGroupName { get; set; }
        public string? Color { get; set; }
        public int? Rank { get; set; }
    }

    public class ImportProductGroupsRequest
    {
        public int CompanyId { get; set; }
        public bool SkipDuplicates { get; set; }
        public bool MergeDuplicates { get; set; }
        public List<ImportProductGroupRow> Rows { get; set; } = [];
    }

    public class ImportProductGroupsResult
    {
        public int Created { get; set; }
        public int Updated { get; set; }
        public int Skipped { get; set; }
        public List<string> Errors { get; set; } = [];
        public List<string> Warnings { get; set; } = [];

        /// <summary>
        /// Every group the import named — rows and the parents they point at —
        /// with its id, whether it was created, merged or skipped. Lets a client
        /// that built the same groups offline swap its temporary ids for these.
        /// Empty when the import could not be saved.
        /// </summary>
        public List<ImportedGroupRef> Groups { get; set; } = [];
    }

    public class ImportedGroupRef
    {
        public string Name { get; set; } = "";
        public int Id { get; set; }
        public int? ParentGroupId { get; set; }
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