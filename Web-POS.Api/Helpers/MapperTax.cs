using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperTax
    {
        public static TaxDto MapToTaxDto(Tax tax)
        {
            return new TaxDto
            {
                Id = tax.Id,
                Name = tax.Name,
                Rate = tax.Rate,
                Code = tax.Code,
                IsFixed = tax.IsFixed,
                IsTaxOnTotal = tax.IsTaxOnTotal,
                IsEnabled = tax.IsEnabled,
                CompanyId = tax.CompanyId,
                LastModified = tax.LastModified
            };
        }
    }
}