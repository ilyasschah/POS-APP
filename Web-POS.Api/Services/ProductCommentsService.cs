using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class ProductCommentService
    {
        private readonly ProductCommentRepository _repository;

        public ProductCommentService(ProductCommentRepository repository)
        {
            _repository = repository;
        }

        public async Task<ProductComment> Create(CreateProductCommentRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Comment))
                throw new InvalidOperationException("Comment cannot be empty.");

            if (!await _repository.ProductExistsAsync(req.ProductId))
                throw new InvalidOperationException($"Product with Id '{req.ProductId}' does not exist.");

            var entity = ProductComment.Create(req.ProductId, req.Comment.Trim());
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateProductCommentRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"ProductComment with ID '{id}' not found.");

            if (string.IsNullOrWhiteSpace(req.Comment))
                throw new InvalidOperationException("Comment cannot be empty.");

            if (!await _repository.ProductExistsAsync(req.ProductId))
                throw new InvalidOperationException($"Product with Id '{req.ProductId}' does not exist.");

            entity.Update(req.ProductId, req.Comment.Trim());
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
