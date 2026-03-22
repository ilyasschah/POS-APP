using Api.Domain;
using Api.Models;

namespace Api.Helpers
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
