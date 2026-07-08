using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Template")]
    public class Template
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(255)]
        public string Name { get; set; } = default!;

        [Required]
        public string Value { get; set; } = default!;

        public Template() { }

        private Template(string name, string value)
        {
            Name = name;
            Value = value;
        }

        public static Template Create(string name, string value)
            => new(name, value);

        public void Update(string name, string value)
        {
            Name = name;
            Value = value;
        }
    }
}
