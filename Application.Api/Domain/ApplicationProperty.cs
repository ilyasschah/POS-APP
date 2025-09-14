using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ApplicationProperty")]
    public class ApplicationProperty
    {
        [Key]
        [MaxLength(255)]
        public string Name { get; set; } = default!;

        public string? Value { get; set; }

        public ApplicationProperty() { }

        private ApplicationProperty(string name, string? value)
        {
            Name = name;
            Value = value;
        }

        public static ApplicationProperty Create(string name, string? value)
            => new(name, value);

        public void Update(string name, string? value)
        {
            Name = name;
            Value = value;
        }
    }
}
