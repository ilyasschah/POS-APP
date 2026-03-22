using Api.Repository;
using Api.Domain;
using Api.Models;

namespace Api.Services
{
    public class PosPrinterSettingsService
    {
        private readonly PosPrinterSettingsRepository _repository;

        public PosPrinterSettingsService(PosPrinterSettingsRepository repository)
        {
            _repository = repository;
        }

        public async Task<PosPrinterSettings> Create(CreatePosPrinterSettingsRequest req)
        {
            if (await _repository.ExistsByPrinterNameAsync(req.PrinterName))
                throw new InvalidOperationException($"A printer with name '{req.PrinterName}' already exists.");

            var entity = PosPrinterSettings.Create(
                req.PrinterName,
                req.PaperWidth ?? 32
            );

            entity.Header = req.Header;
            entity.Footer = req.Footer;
            entity.FeedLines = req.FeedLines ?? 0;
            entity.CutPaper = req.CutPaper ?? true;
            entity.PrintBitmap = req.PrintBitmap ?? false;
            entity.OpenCashDrawer = req.OpenCashDrawer ?? true;
            entity.CashDrawerCommand = req.CashDrawerCommand;
            entity.HeaderAlignment = req.HeaderAlignment ?? 0;
            entity.FooterAlignment = req.FooterAlignment ?? 0;
            entity.IsFormattingEnabled = req.IsFormattingEnabled ?? true;
            entity.PrinterType = req.PrinterType ?? 0;
            entity.NumberOfCopies = req.NumberOfCopies ?? 1;
            entity.CodePage = req.CodePage ?? -1;
            entity.CharacterSet = req.CharacterSet ?? -1;

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdatePosPrinterSettingsRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"Printer settings with ID '{id}' not found.");

            var sameName = await _repository.GetByPrinterNameAsync(req.PrinterName);
            if (sameName != null && sameName.Id != id)
                throw new InvalidOperationException($"Another printer with name '{req.PrinterName}' already exists.");

            entity.Update(
                req.PrinterName,
                req.PaperWidth,
                req.Header,
                req.Footer,
                req.FeedLines,
                req.CutPaper,
                req.PrintBitmap,
                req.OpenCashDrawer,
                req.CashDrawerCommand,
                req.HeaderAlignment,
                req.FooterAlignment,
                req.IsFormattingEnabled,
                req.PrinterType,
                req.NumberOfCopies,
                req.CodePage,
                req.CharacterSet
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
