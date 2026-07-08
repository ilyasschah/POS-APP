using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    /// <summary>
    /// Global, read-only reference table shared by all companies (e.g. Sales,
    /// Expenses, Inventory). Not company-scoped, not editable through the API.
    /// </summary>
    [Table("DocumentCategory")]
    public class DocumentCategory
    {
        [Key]
        public int Id { get; set; }
        public string? Name { get; set; }
        public string? LanguageKey { get; set; }

        public DocumentCategory() { }
    }
}
