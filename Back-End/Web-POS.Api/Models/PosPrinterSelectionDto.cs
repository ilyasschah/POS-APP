namespace Api.Models
{
    public class PosPrinterSelectionDto
    {
        public int Id { get; set; }
        public string Key { get; set; } = default!;
        public string? PrinterName { get; set; }
        public bool IsEnabled { get; set; }
    }

    public class CreatePosPrinterSelectionRequest
    {
        public required string Key { get; set; }
        public string? PrinterName { get; set; }
        public bool? IsEnabled { get; set; }
    }

    public class UpdatePosPrinterSelectionRequest
    {
        public required string Key { get; set; }
        public string? PrinterName { get; set; }
        public required bool IsEnabled { get; set; }
    }
}
