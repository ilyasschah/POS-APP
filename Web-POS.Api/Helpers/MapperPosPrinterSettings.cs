using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPosPrinterSettings
    {
        public static PosPrinterSettingsDto MapToPosPrinterSettingsDto(PosPrinterSettings entity)
        {
            return new PosPrinterSettingsDto
            {
                Id = entity.Id,
                PrinterName = entity.PrinterName,
                PaperWidth = entity.PaperWidth,
                Header = entity.Header,
                Footer = entity.Footer,
                FeedLines = entity.FeedLines,
                CutPaper = entity.CutPaper,
                PrintBitmap = entity.PrintBitmap,
                OpenCashDrawer = entity.OpenCashDrawer,
                CashDrawerCommand = entity.CashDrawerCommand,
                HeaderAlignment = entity.HeaderAlignment,
                FooterAlignment = entity.FooterAlignment,
                IsFormattingEnabled = entity.IsFormattingEnabled,
                PrinterType = entity.PrinterType,
                NumberOfCopies = entity.NumberOfCopies,
                CodePage = entity.CodePage,
                CharacterSet = entity.CharacterSet
            };
        }
    }
}
