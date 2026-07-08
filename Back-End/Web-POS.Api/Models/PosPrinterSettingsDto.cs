namespace Api.Models
{
    public class PosPrinterSettingsDto
    {
        public int Id { get; set; }
        public string PrinterName { get; set; } = default!;
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
    }

    public class CreatePosPrinterSettingsRequest
    {
        public required string PrinterName { get; set; }
        public int? PaperWidth { get; set; }               // null => default 32
        public string? Header { get; set; }
        public string? Footer { get; set; }
        public int? FeedLines { get; set; }                // null => 0
        public bool? CutPaper { get; set; }                // null => true
        public bool? PrintBitmap { get; set; }             // null => false
        public bool? OpenCashDrawer { get; set; }          // null => true
        public string? CashDrawerCommand { get; set; }
        public int? HeaderAlignment { get; set; }          // null => 0
        public int? FooterAlignment { get; set; }          // null => 0
        public bool? IsFormattingEnabled { get; set; }     // null => true
        public int? PrinterType { get; set; }              // null => 0
        public int? NumberOfCopies { get; set; }           // null => 1
        public int? CodePage { get; set; }                 // null => -1
        public int? CharacterSet { get; set; }             // null => -1
    }

    public class UpdatePosPrinterSettingsRequest
    {
        public required string PrinterName { get; set; }
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
    }
}
