using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class DocumentCategoryService
    {    
        public DocumentCategoryRepository _documentCategoryRepository;
        public DocumentCategoryService(DocumentCategoryRepository documentCategoryRepository)
        {
            _documentCategoryRepository = documentCategoryRepository;
        }
        public async Task<bool> Create(CreateDocumentCategoryRequest request) // rkia why some times i dont use this beause i cant create and send the id 
        {
            var dcexists = _documentCategoryRepository.ExistsById(request.Name);
            if (dcexists)
                throw new InvalidOperationException($"A Document Category with the Name '{request.Name}' already exists.");
            var newDocumentCategory = DocumentCategory.Create(request.Name , request.LanguageKey);
            await _documentCategoryRepository.AddAsync(newDocumentCategory);
            return true;
        }
        public async Task<bool> Delete(int id)
        {
            var documentCategory = await _documentCategoryRepository.GetByIdAsync(id);
            if (documentCategory == null)
                throw new InvalidOperationException($"A Document Category with the ID '{id}' Dont Exists.");
            await _documentCategoryRepository.DeleteAsync(documentCategory);
            return true;
        }
    }
}
