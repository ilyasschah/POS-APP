using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Country")]
    public class Country
    {
        [Key]
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public string? Name { get; set; }
        public string? Code { get; set; }
        private Country(int companyId, string name, string? code)
        {
            CompanyId = companyId;
            Name = name;
            Code = code;
        }

        public Country() { }

        public static Country Create(int companyId, string name, string? code)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("Name cannot be null or whitespace.", nameof(name));
            }
            return new Country(companyId, name, code);
        }
        public void UpdateName(string newName)
        {
            if (string.IsNullOrWhiteSpace(newName))
            {
                throw new ArgumentException("Name cannot be null or whitespace.", nameof(newName));
            }
            Name = newName;
        }
    }
}