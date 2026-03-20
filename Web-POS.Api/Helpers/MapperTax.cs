using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public class MapperTax
    {
        public static TaxDto MapToTax(Tax tax)
        {
            return new TaxDto
            {
                Id = tax.Id,
                Name = tax.Name,
                Rate = tax.Rate,
                Code = tax.Code,
                IsFixed = tax.IsFixed,
                IsTaxOnTotal = tax.IsTaxOnTotal,
                IsEnabled = tax.IsEnabled
            };
        }

        public static Tax MapToTax(CreateTaxRequestDto createDto, int companyId)
        {
            if (createDto == null)
            {
                throw new ArgumentNullException(nameof(createDto));
            }
            return Tax.Create(
                companyId,
                createDto.Name,
                createDto.Rate,
                createDto.Code,
                createDto.IsFixed,
                createDto.IsTaxOnTotal,
                createDto.IsEnabled
            );
        }
    }
}