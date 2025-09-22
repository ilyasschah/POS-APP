using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Tax")]
    public class Tax
    {
        [Key]
        public int Id { get; set; }
        [Required]
        public string Name { get; set; }
        [Required]
        public decimal Rate { get; set; }
        public string? Code { get; set; }
        [Required]
        public bool IsFixed { get; set; }
        [Required]
        public bool IsTaxOnTotal { get; set; }
        [Required]
        public bool IsEnabled { get; set; }


        private Tax(string name, decimal rate, string code ,bool isfixed, bool istaxontotal, bool isenabled)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be empty", nameof(name));

            if (rate <= 0)
                throw new ArgumentException("tax rate cannot be empty", nameof(rate));

            Name = name.Trim();
            Rate = rate;
            Code = code.Trim();
            IsFixed = isfixed;
            IsTaxOnTotal = istaxontotal;
            IsEnabled = isenabled;
        }

        public Tax() { }
        public static Tax Create(string name, decimal rate, string code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            return new Tax(name, rate,code,isfixed,istaxontotal,isenabled);
        }

        public void UpdateComment(string name, decimal rate, string code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be empty", nameof(name));
            if (rate <= 0)
                throw new ArgumentException("tax rate cannot be empty", nameof(rate));
            Name = name.Trim();
            Rate = rate;
            Code = code?.Trim();
            IsFixed = isfixed;
            IsTaxOnTotal = istaxontotal;
            IsEnabled = isenabled;
        }
        
    }
}