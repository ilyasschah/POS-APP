using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Api.Domain
{
    [Table("SecurityKey")]
    [PrimaryKey(nameof(CompanyId), nameof(Name))]
    public class SecurityKey
    {
        public int CompanyId { get; private set; }

        [MaxLength(100)]
        public string Name { get; private set; }

        public int Level { get; private set; }

        public SecurityKey() { }

        private SecurityKey(int companyId, string name, int level)
        {
            CompanyId = companyId;
            Name = name;
            Level = level;
        }

        public static SecurityKey Create(int companyId, string name, int level)
        {
            if (companyId <= 0)
                throw new ArgumentException("Invalid CompanyId", nameof(companyId));

            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Security Name cannot be empty or whitespace.", nameof(name));

            if (level < 0 || level > 1)
                throw new ArgumentException("Level must be 0 (Cashier) or 1 (Admin).", nameof(level));

            return new SecurityKey(companyId, name, level);
        }

        public void UpdateLevel(int newLevel)
        {
            if (newLevel < 0 || newLevel > 1)
                throw new ArgumentException("Level must be 0 (Cashier) or 1 (Admin).", nameof(newLevel));

            Level = newLevel;
        }
    }
}