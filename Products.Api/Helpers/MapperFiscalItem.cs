using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperFiscalItem
    {
        public static FiscalItemDto MapToFiscalItemDto(FiscalItem entity)
        {
            return new FiscalItemDto
            {
                PLU = entity.PLU,
                Name = entity.Name,
                VAT = entity.VAT
            };
        }
    }
}