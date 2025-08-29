using Documents.Api.Domain;
using Documents.Api.Repository;

namespace Documents.Api.Services
{
    public class DocumentItemExpirationDateService
    {
        public DocumentItemExpirationDateRepository _repository;
        public DocumentItemExpirationDateService (DocumentItemExpirationDateRepository expirationDateRepository )
        {
            _repository = expirationDateRepository;
        }
        public async Task<bool> CreateByDocumentItemId(int documentItemId, DateTime expirationdate)
        {
            var entity = _repository.ExistsByDocumentItemId(documentItemId);
            if (entity == true)
                throw new InvalidOperationException($"A Document Item Expiration Date with the Document Item ID '{documentItemId}' already exists.");
            var newentity = DocumentItemExpirationDate.Create(documentItemId, expirationdate);
            await _repository.AddAsync(newentity);
            return true;
        }
        public async Task<bool> UpdateByDocumentItemId(int documentItemId, DateTime expirationdate)
        {
            var entity = await _repository.Getbydocumentidtoupdated(documentItemId);
            if (entity == null)
                throw new InvalidOperationException($"A Document Item Expiration Date with the Document Item ID '{documentItemId}' Dont Exists.");
            entity.UpdateExpirationDate(expirationdate);
            await _repository.UpdateAsync(entity);
            return true;
        }
        public async Task<bool> DeleteByDocumentItemId(int documentItemId)
        {
            var entity = await _repository.Getbydocumentidtoupdated(documentItemId);
            if (entity == null)
                throw new InvalidOperationException($"A Document Item Expiration Date with the Document Item ID '{documentItemId}' Dont Exists.");
            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
