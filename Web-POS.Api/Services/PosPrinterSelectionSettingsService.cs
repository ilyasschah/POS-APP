using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class PosPrinterSelectionSettingsService
    {
        private readonly PosPrinterSelectionSettingsRepository _repository;

        public PosPrinterSelectionSettingsService(PosPrinterSelectionSettingsRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosPrinterSelectionSettings> Create(CreatePosPrinterSelectionSettingsRequest req)
        {
            if (!await _repository.SelectionExistsAsync(req.PosPrinterSelectionId))
                throw new InvalidOperationException($"PosPrinterSelection with Id '{req.PosPrinterSelectionId}' does not exist.");

            var entity = PosPrinterSelectionSettings.Create(
                posPrinterSelectionId: req.PosPrinterSelectionId,
                paperWidth: req.PaperWidth ?? 32,
                header: req.Header,
                footer: req.Footer,
                feedLines: req.FeedLines ?? 0,
                cutPaper: req.CutPaper ?? true,
                printBitmap: req.PrintBitmap ?? false,
                openCashDrawer: req.OpenCashDrawer ?? true,
                cashDrawerCommand: req.CashDrawerCommand,
                headerAlignment: req.HeaderAlignment ?? 0,
                footerAlignment: req.FooterAlignment ?? 0,
                isFormattingEnabled: req.IsFormattingEnabled ?? true,
                printerType: req.PrinterType ?? 0,
                numberOfCopies: req.NumberOfCopies ?? 1,
                codePage: req.CodePage ?? -1,
                characterSet: req.CharacterSet ?? -1,
                margin: req.Margin ?? 0,
                leftMargin: req.LeftMargin ?? 0m,
                topMargin: req.TopMargin ?? 0m,
                rightMargin: req.RightMargin ?? 0m,
                bottomMargin: req.BottomMargin ?? 0m,
                printBarcode: req.PrintBarcode ?? true,
                fontName: req.FontName,
                fontSizePercent: req.FontSizePercent ?? 100m,
                printLogoFullWidth: req.PrintLogoFullWidth ?? false
            );

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdatePosPrinterSelectionSettingsRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"PosPrinterSelectionSettings with ID '{id}' not found.");

            if (!await _repository.SelectionExistsAsync(req.PosPrinterSelectionId))
                throw new InvalidOperationException($"PosPrinterSelection with Id '{req.PosPrinterSelectionId}' does not exist.");

            entity.Update(
                posPrinterSelectionId: req.PosPrinterSelectionId,
                paperWidth: req.PaperWidth,
                header: req.Header,
                footer: req.Footer,
                feedLines: req.FeedLines,
                cutPaper: req.CutPaper,
                printBitmap: req.PrintBitmap,
                openCashDrawer: req.OpenCashDrawer,
                cashDrawerCommand: req.CashDrawerCommand,
                headerAlignment: req.HeaderAlignment,
                footerAlignment: req.FooterAlignment,
                isFormattingEnabled: req.IsFormattingEnabled,
                printerType: req.PrinterType,
                numberOfCopies: req.NumberOfCopies,
                codePage: req.CodePage,
                characterSet: req.CharacterSet,
                margin: req.Margin,
                leftMargin: req.LeftMargin,
                topMargin: req.TopMargin,
                rightMargin: req.RightMargin,
                bottomMargin: req.BottomMargin,
                printBarcode: req.PrintBarcode,
                fontName: req.FontName,
                fontSizePercent: req.FontSizePercent,
                printLogoFullWidth: req.PrintLogoFullWidth
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
