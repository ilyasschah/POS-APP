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
                Name = tax.Name,
                Rate = tax.Rate,
                Code = tax.Code,
                IsFixed = tax.IsFixed,
                IsTaxOnTotal = tax.IsTaxOnTotal,
                IsEnabled = tax.IsEnabled
            };
        }
        public static Tax MapToTax(CreateTaxRequestDto createDto)
        {
            if (createDto == null)
            {
                throw new ArgumentNullException(nameof(createDto));
            }

            return new Tax
            {
                Name = createDto.Name,
                Rate = createDto.Rate,
                Code = createDto.Code,
                IsFixed = createDto.IsFixed,
                IsTaxOnTotal = createDto.IsTaxOnTotal,
                IsEnabled = createDto.IsEnabled
            };
        }
        public static Tax MapToTax(UpdateTaxRequestDto updateDto)
        {
            if (updateDto == null)
                throw new ArgumentNullException(nameof(updateDto));
            return new Tax
            {
                Name = updateDto.Name,
                Rate = updateDto.Rate,
                Code = updateDto.Code,
                IsFixed = updateDto.IsFixed,
                IsTaxOnTotal = updateDto.IsTaxOnTotal,
                IsEnabled = updateDto.IsEnabled
            };
        }
    }
}
