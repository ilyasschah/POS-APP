using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("Tax")]
    public class Tax
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        [Required]
        public string Name { get; private set; }

        [Required]
        public decimal Rate { get; private set; }

        public string? Code { get; private set; } = null;

        [Required]
        public bool IsFixed { get; private set; }

        [Required]
        public bool IsTaxOnTotal { get; private set; }

        [Required]
        public bool IsEnabled { get; private set; }

        public Tax() { }

        private Tax(int companyId, string name, decimal rate, string? code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            if (companyId <= 0)
                throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be empty", nameof(name));
            if (rate <= 0)
                throw new ArgumentException("Tax rate must be greater than zero", nameof(rate));

            CompanyId = companyId;
            Name = name.Trim();
            Rate = rate;
            Code = code?.Trim();
            IsFixed = isfixed;
            IsTaxOnTotal = istaxontotal;
            IsEnabled = isenabled;
        }

        public static Tax Create(int companyId, string name, decimal rate, string? code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            return new Tax(companyId, name, rate, code, isfixed, istaxontotal, isenabled);
        }
        public void UpdateDetails(string name, decimal rate, string? code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name cannot be empty", nameof(name));
            if (rate <= 0)
                throw new ArgumentException("Tax rate must be greater than zero", nameof(rate));

            Name = name.Trim();
            Rate = rate;
            Code = code?.Trim();
            IsFixed = isfixed;
            IsTaxOnTotal = istaxontotal;
            IsEnabled = isenabled;
        }
    }
}