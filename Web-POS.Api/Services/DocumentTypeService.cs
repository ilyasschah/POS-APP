using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class DocumentTypeService
    {
        private readonly DocumentTypeRepository _repository;

        public DocumentTypeService(DocumentTypeRepository repository)
        {
            _repository = repository;
        }

        public async Task<bool> Create(CreateDocumentTypeRequest request)
        {
            var entity = DocumentType.Create(
                request.Name,
                request.Code,
                request.DocumentCategoryId,
                request.WarehouseId,
                request.StockDirection,
                request.EditorType,
                request.PrintTemplate,
                request.PriceType,
                request.LanguageKey
            );

            await _repository.AddAsync(entity);
            return true;
        }

        //public async Task<bool> Update(int id, UpdateDocumentTypeRequest request)
        //{
        //    var entity = await _repository.GetByIdAsync(id);
        //    if (entity == null)
        //        throw new InvalidOperationException($"Document Type with ID '{id}' not found.");

        //    entity.Update(
        //        request.Name,
        //        request.Code,
        //        request.DocumentCategoryId,
        //        request.WarehouseId,
        //        request.StockDirection,
        //        request.EditorType,
        //        request.PrintTemplate,
        //        request.PriceType,
        //        request.LanguageKey
        //    );

        //    await _repository.UpdateAsync(entity);
        //    return true;
        //}

        //public async Task<bool> Delete(int id)
        //{
        //    var entity = await _repository.GetByIdAsync(id);
        //    if (entity == null)
        //        throw new InvalidOperationException($"Document Type with ID '{id}' not found.");

        //    await _repository.DeleteAsync(entity);
        //    return true;
        //}
    }
}
