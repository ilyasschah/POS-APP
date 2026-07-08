using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("ApplicationProperty")]
    public class ApplicationProperty : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public string? Name { get; private set; }
        public string? Value { get; private set; }
        public DateTime LastModified { get; set; } = DateTime.UtcNow;
        [ForeignKey(nameof(CompanyId))]
        public virtual Company? Company { get; private set; }

        private ApplicationProperty(int companyId, string name, string value)
        {
            if (companyId <= 0)
                throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Name must not be empty.", nameof(name));

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
            Value = value;
        }
    }
}