using Products.Api.Domain;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class BarcodeService
    {
        public BarcodeRepository _barcodeRepository;
        public BarcodeService(BarcodeRepository barcodeRepository)
        {
            _barcodeRepository = barcodeRepository;
        }
        public async Task<bool> Create(string valeu, int productsid)
        {
            var cexists = _barcodeRepository.Exists(valeu);
            if (cexists == true)
                throw new InvalidOperationException($"A Barcode with the Value '{valeu}' already exists.");
            var newbarcode = Barcode.Create(valeu, productsid);
            await _barcodeRepository.Add(newbarcode);
            return true;
        }
        public async Task<bool> Update(int id, string valeu)
        {
            var barcode = await _barcodeRepository.GetBarCodeByIdQuery(id);
            if (barcode == null)
                throw new InvalidOperationException($"A Barcode with the ID '{id}' Dont Exists.");
            
            barcode.UpdateValue(valeu);
            await _barcodeRepository.UpdateAsync(barcode);
            return true;
        }
        public async Task<bool> Delete(int id)
        {
            var barcode = await _barcodeRepository.GetBarCodeByIdQuery(id);
            if (barcode == null)
                throw new InvalidOperationException($"A Barcode with the ID '{id}' Dont Exists.");
            await _barcodeRepository.DeleteAsync(barcode);
            return true;
        }
    }
}
