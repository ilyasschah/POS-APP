namespace Products.Api.Models
{
    public class PosPrinterSelectionSettingsDto
    {
        public int Id { get; set; }
        public int PosPrinterSelectionId { get; set; }
        public int PaperWidth { get; set; }
        public string? Header { get; set; }
        public string? Footer { get; set; }
        public int FeedLines { get; set; }
        public bool CutPaper { get; set; }
        public bool PrintBitmap { get; set; }
        public bool OpenCashDrawer { get; set; }
        public string? CashDrawerCommand { get; set; }
        public int HeaderAlignment { get; set; }
        public int FooterAlignment { get; set; }
        public bool IsFormattingEnabled { get; set; }
        public int PrinterType { get; set; }
        public int NumberOfCopies { get; set; }
        public int CodePage { get; set; }
        public int CharacterSet { get; set; }
        public int Margin { get; set; }
        public decimal LeftMargin { get; set; }
        public decimal TopMargin { get; set; }
        public decimal RightMargin { get; set; }
        public decimal BottomMargin { get; set; }
        public bool PrintBarcode { get; set; }
        public string? FontName { get; set; }
        public decimal FontSizePercent { get; set; }
        public bool PrintLogoFullWidth { get; set; }
    }

    public class CreatePosPrinterSelectionSettingsRequest
    {
        public required int PosPrinterSelectionId { get; set; }
        public int? PaperWidth { get; set; }
        public string? Header { get; set; }
        public string? Footer { get; set; }
        public int? FeedLines { get; set; }
        public bool? CutPaper { get; set; }
        public bool? PrintBitmap { get; set; }
        public bool? OpenCashDrawer { get; set; }
        public string? CashDrawerCommand { get; set; }
        public int? HeaderAlignment { get; set; }
        public int? FooterAlignment { get; set; }
        public bool? IsFormattingEnabled { get; set; }
        public int? PrinterType { get; set; }
        public int? NumberOfCopies { get; set; }
        public int? CodePage { get; set; }
        public int? CharacterSet { get; set; }
        public int? Margin { get; set; }
        public decimal? LeftMargin { get; set; }
        public decimal? TopMargin { get; set; }
        public decimal? RightMargin { get; set; }
        public decimal? BottomMargin { get; set; }
        public bool? PrintBarcode { get; set; }
        public string? FontName { get; set; }
        public decimal? FontSizePercent { get; set; }
        public bool? PrintLogoFullWidth { get; set; }
    }

    public class UpdatePosPrinterSelectionSettingsRequest
    {
        public required int PosPrinterSelectionId { get; set; }
        public required int PaperWidth { get; set; }
        public string? Header { get; set; }
        public string? Footer { get; set; }
        public required int FeedLines { get; set; }
        public required bool CutPaper { get; set; }
        public required bool PrintBitmap { get; set; }
        public required bool OpenCashDrawer { get; set; }
        public string? CashDrawerCommand { get; set; }
        public required int HeaderAlignment { get; set; }
        public required int FooterAlignment { get; set; }
        public required bool IsFormattingEnabled { get; set; }
        public required int PrinterType { get; set; }
        public required int NumberOfCopies { get; set; }
        public required int CodePage { get; set; }
        public required int CharacterSet { get; set; }
        public required int Margin { get; set; }
        public required decimal LeftMargin { get; set; }
        public required decimal TopMargin { get; set; }
        public required decimal RightMargin { get; set; }
        public required decimal BottomMargin { get; set; }
        public required bool PrintBarcode { get; set; }
        public string? FontName { get; set; }
        public required decimal FontSizePercent { get; set; }
        public required bool PrintLogoFullWidth { get; set; }
    }
}
