using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Tax")]
    public class Tax
    {
        [Key]
        public int Id { get;  set; }
        public int CompanyId { get;  set; }
        public string Name { get;  set; }
        public decimal Rate { get;  set; }
        public string? Code { get;  set; }
        public bool IsFixed { get;  set; }
        public bool IsTaxOnTotal { get;  set; }
        public bool IsEnabled { get;  set; }
        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }
        

        private Tax(int companyId, string name, decimal rate, string? code, bool isfixed, bool istaxontotal, bool isenabled)
        {
            CompanyId = companyId;
            Name = name.Trim();
            Rate = rate;
            Code = code?.Trim();
            IsFixed = isfixed;
            IsTaxOnTotal = istaxontotal;
            IsEnabled = isenabled;
        }
        public Tax() { }
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