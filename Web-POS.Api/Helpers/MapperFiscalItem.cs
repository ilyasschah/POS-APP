using Api.Domain;
using Api.Models;

namespace Api.Helpers
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