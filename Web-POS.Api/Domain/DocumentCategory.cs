using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentCategory")]
    public class DocumentCategory
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string? Name { get; set; }
        public string? LanguageKey  { get; set; }

        public DocumentCategory (string name , string languagekey, int companyId)
        {
            Name = name;
            LanguageKey = languagekey;
            CompanyId = companyId;
        }
        public DocumentCategory()
        {
        }
        public static DocumentCategory Create(string name , string languagekey, int companyId)
        {
            return new DocumentCategory(name, languagekey, companyId);
        }

    }
}