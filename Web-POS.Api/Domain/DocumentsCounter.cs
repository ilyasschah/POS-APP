using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Counter")]
    public class DocumentsCounter
    {
        [Key]
        public string Name { get; set; }
        public int Value { get; set; }

        private DocumentsCounter(string name, int value)
        {
            Name = name;
            Value = value;
        }

        public DocumentsCounter() { }

        public static DocumentsCounter Create(string name, int value)
        {
            return new DocumentsCounter(name, value);
        }

        public void UpdateValue(int newValue)
        {
            Value = newValue;
        }
    }
}