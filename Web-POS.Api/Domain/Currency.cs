using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Currency")]
    public class Currency
    {
        [Key]
        public int Id { get; set; }

        [Required, MaxLength(100)]
        public string Name { get; set; } = default!;

        [MaxLength(10)]
        public string? Code { get; set; }

        public Currency() { }

        private Currency(string name, string? code)
        {
            Name = name;
            Code = code;
        }

        public static Currency Create(string name, string? code)
            => new(name, code);

        public void Update(string name, string? code)
        {
            Name = name;
            Code = code;
        }
    }
}
