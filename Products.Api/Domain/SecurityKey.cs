using Newtonsoft.Json.Linq;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain
{
    [Table("SecurityKey")]
    public class SecurityKey
    {
        [Key]
        public string Name { get; set; }
        public int? Level { get; set; }


        private SecurityKey(string name, int level)
        {
            Name = name;
            Level = level;
        }
        public SecurityKey() { }
        public static SecurityKey Create(string name, int level)
        {
            if (name == null)
            {
                throw new ArgumentException("Security Name Cant be white scapce.", nameof(name));
            }
            return new SecurityKey(name, level);
        }
        //public void UpdateValue(string newValue)
        //{
        //    if (string.IsNullOrWhiteSpace(newValue))
        //    {
        //        throw new ArgumentException("Value cannot be null or whitespace.", nameof(newValue));
        //    }
        //    Value = newValue;
        //}
    }
}