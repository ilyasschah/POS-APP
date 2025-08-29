using Documents.Api.Domain;
using Documents.Api.Models;
using Documents.Api.Repository;
namespace Documents.Api.Services
{
    public class DocumentItemService
    {
        public DocumentItemRepository _documentItemRepository;
        public DocumentItemService(DocumentItemRepository documentItemRepository)
        {
            _documentItemRepository = documentItemRepository;
        }
        public async Task<bool> Create(CreateDocumentItemRequest request)
        {
            
            var newDocumentItem = DocumentItem.Create(
                request.DocumentId, 
                request.ProductId, 
                request.Quantity, 
                request.PriceBeforeTax, 
                request.Price, 
                request.Discount, 
                request.DiscountType, 
                request.ProductCost, 
                request.PriceBeforeTaxAfterDiscount,
                request.PriceAfterDiscount,
                request.Total, 
                request.TotalAfterDocumentDiscount, 
                request.DiscountApplyRule);
            await _documentItemRepository.Add(newDocumentItem);
            return true;
        }
        public async Task<bool> Update (decimal updatedquantity , int id)
        {
            var documentItem = await _documentItemRepository.GetDocumentItemByIdAsync(id);
            if (documentItem == null)
                throw new InvalidOperationException($"A Document Item with the ID '{id}' Dont Exists.");
            documentItem.UpdateQuantity(updatedquantity);
            await _documentItemRepository.UpdateAsync(documentItem);
            return true;
        }
        public async Task<bool> Delete(int id)
        {
            var documentItem = await _documentItemRepository.GetDocumentItemByIdAsync(id);
            if (documentItem == null)
                throw new InvalidOperationException($"A Document Item with the ID '{id}' Dont Exists.");
            await _documentItemRepository.DeleteAsync(documentItem);
            return true;
        }
        

    }
}