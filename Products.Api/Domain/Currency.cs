using Newtonsoft.Json.Linq;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Currency")]
    public class Currency
    {
        [Key]
        public int Id { get; set; }
        public string? Name { get; set; } 
        public string? Code { get; set; } 

        private Currency(string name, string code)
        {
            Name = name;
            Code = code;
        }
        public Currency() { }
        public static Currency Create(string name, string code)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("Name must not be null or whitespace.", nameof(name));
            }
            if (string.IsNullOrWhiteSpace(code))
            {
                throw new ArgumentException("Code must not be null or whitespace.", nameof(code));
            }
            return new Currency(name, code);
        }
    }
}
