using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ApplicationProperty")]
    public class ApplicationProperty
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        [Required]
        [MaxLength(255)]
        public string Name { get; private set; }

        [Required]
        public string Value { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }

        private ApplicationProperty(int companyId, string name, string value)
        {
            if (companyId <= 0)
                throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name must not be empty.", nameof(name));
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("Value must not be empty.", nameof(value));

            CompanyId = companyId;
            Name = name.Trim();
            Value = value;
        }

        public ApplicationProperty() { }

        public static ApplicationProperty Create(int companyId, string name, string value)
        {
            return new ApplicationProperty(companyId, name, value);
        }

        public void UpdateValue(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("Value must not be empty.", nameof(value));

            Value = value;
        }
    }
}