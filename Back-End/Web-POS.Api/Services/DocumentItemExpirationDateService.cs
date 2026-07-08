using Api.Domain;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Services
{
    public class DocumentItemExpirationDateService
    {
        private readonly DocumentItemExpirationDateRepository _repository;
        private readonly DocumentItemRepository _documentItemRepository;

        public DocumentItemExpirationDateService(
            DocumentItemExpirationDateRepository repository,
            DocumentItemRepository documentItemRepository)
        {
            _repository = repository;
            _documentItemRepository = documentItemRepository;
        }

        public async Task<DocumentItemExpirationDateDto?> Get(int documentItemId, int companyId)
        {
            var entity = await _repository.GetByIdAsync(documentItemId, companyId);
            return entity == null ? null : MapperDocumentItemExpirationDate.MapToDocumentItemExpirationDateDto(entity);
        }

        public async Task<DocumentItemExpirationDateDto> Create(CreateDocumentItemExpirationDateRequest req, int companyId)
        {
            var documentItem = await _documentItemRepository.GetByIdAsync(req.DocumentItemId, companyId);
            if (documentItem == null)
                throw new InvalidOperationException("Document item not found.");

            var exists = await _repository.ExistsAsync(req.DocumentItemId, companyId);
            if (exists)
                throw new InvalidOperationException("An expiration date already exists for this document item.");

            var newExpirationDate = DocumentItemExpirationDate.Create(
                req.DocumentItemId,
                req.ExpirationDate.Date,
                companyId
            );

            await _repository.AddAsync(newExpirationDate);

            return MapperDocumentItemExpirationDate.MapToDocumentItemExpirationDateDto(newExpirationDate);
        }

        public async Task<DocumentItemExpirationDateDto> Update(UpdateDocumentItemExpirationDateRequest req, int companyId)
        {
            var entityToUpdate = await _repository.GetByIdAsync(req.DocumentItemId, companyId);
            if (entityToUpdate == null)
                throw new InvalidOperationException("Expiration date not found for this document item.");

            entityToUpdate.UpdateExpirationDate(req.ExpirationDate.Date);
            await _repository.UpdateAsync(entityToUpdate);

            return MapperDocumentItemExpirationDate.MapToDocumentItemExpirationDateDto(entityToUpdate);
        }

        public async Task<bool> Delete(int documentItemId, int companyId)
        {
            var entityToDelete = await _repository.GetByIdAsync(documentItemId, companyId);
            if (entityToDelete == null)
                throw new InvalidOperationException("Expiration date not found for this document item.");

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}