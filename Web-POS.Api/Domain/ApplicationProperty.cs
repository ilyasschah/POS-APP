using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("ApplicationProperty")]
    public class ApplicationProperty
    {
        [Key]
        [MaxLength(255)]
        public string Name { get; set; }
        public string Value { get; set; }
        public int CompanyId { get; set; }
        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; set; }
        public ApplicationProperty() { }

        private ApplicationProperty(string name, string value, int companyId)
        {
            Name = name;
            Value = value;
            CompanyId = companyId;
        }
        public static ApplicationProperty Create(string name,string value, int companyId)
        {
            return new ApplicationProperty(name, value, companyId);
        }   
        public void Update(string value)
        {
            Value = value;
        }
    }
}