using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Counter")]
    public class DocumentsCounter
    {
        [Key]
        public string? Name { get; set; }
        public int Value { get; set; }
        public int CompanyId { get; private set; }

        private DocumentsCounter(string name, int value, int companyId)
        {
            Name = name;
            Value = value;
            CompanyId = companyId;
        }

        public DocumentsCounter() { }

        public static DocumentsCounter Create(string name, int value, int companyId)
        {
            return new DocumentsCounter(name, value, companyId);
        }

        public void UpdateValue(int newValue)
        {
            Value = newValue;
        }
    }
}