using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperPosPrinterSelectionSettings
    {
        public static PosPrinterSelectionSettingsDto MapToPosPrinterSelectionSettingsDto(PosPrinterSelectionSettings entity)
        {
            return new PosPrinterSelectionSettingsDto
            {
                Id = entity.Id,
                PosPrinterSelectionId = entity.PosPrinterSelectionId,
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
                CharacterSet = entity.CharacterSet,
                Margin = entity.Margin,
                LeftMargin = entity.LeftMargin,
                TopMargin = entity.TopMargin,
                RightMargin = entity.RightMargin,
                BottomMargin = entity.BottomMargin,
                PrintBarcode = entity.PrintBarcode,
                FontName = entity.FontName,
                FontSizePercent = entity.FontSizePercent,
                PrintLogoFullWidth = entity.PrintLogoFullWidth
            };
        }
    }
}
