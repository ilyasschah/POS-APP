using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Services
{
    public class DocumentItemTaxService
    {
        public DocumentItemTaxRepository _documentItemTaxRepository;
        public DocumentItemTaxService(DocumentItemTaxRepository documentItemtaxRepository)
        {
            _documentItemTaxRepository = documentItemtaxRepository;
        }
        public async Task<bool> Create(CreateDocumentItemTaxRequest request)
        {
            var newDocumentItem = DocumentItemTax.Create(
                request.DocumentItemId,
                request.TaxId,
                request.Amount
                );
            await _documentItemTaxRepository.AddAsync(newDocumentItem);
            return true;
        }
        public async Task<bool> Update (decimal amount , int id)
        {
            var documentItem = await _documentItemTaxRepository.Getbydocumentidtoupdated(id);
            if (documentItem == null)
                throw new InvalidOperationException($"A Document Item with the ID '{id}' Dont Exists.");
            documentItem.UpdateAmount(amount);
            await _documentItemTaxRepository.UpdateAsync(documentItem);
            return true;
        }
        public async Task<bool> Delete(int id)
        {
            var documentItem = await _documentItemTaxRepository.Getbydocumentidtoupdated(id);
            if (documentItem == null)
                throw new InvalidOperationException($"A Document Item with the ID '{id}' Dont Exists.");
            await _documentItemTaxRepository.DeleteAsync(documentItem);
            return true;
        }
        
    }
}