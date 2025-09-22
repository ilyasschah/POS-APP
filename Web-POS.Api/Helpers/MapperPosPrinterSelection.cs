using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperPosPrinterSelection
    {
        public static PosPrinterSelectionDto MapToPosPrinterSelectionDto(PosPrinterSelection entity)
        {
            return new PosPrinterSelectionDto
            {
                Id = entity.Id,
                Key = entity.Key,
                PrinterName = entity.PrinterName,
                IsEnabled = entity.IsEnabled
            };
        }
    }
}
