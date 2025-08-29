using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Documents.Api.Domain
{
    [Table("DocumentCategory")]
    public class DocumentCategory
    {
        [Key]
        public int Id { get; set; }
        [Required]
        public string Name { get; set; }
        public string? LanguageKey  { get; set; }

        public DocumentCategory (string name , string languagekey)
        {
            Name = name;
            LanguageKey = languagekey;
        }
        public DocumentCategory()
        {
        }
        public static DocumentCategory Create(string name , string languagekey)
        {
            return new DocumentCategory(name, languagekey);
        }

    }
}