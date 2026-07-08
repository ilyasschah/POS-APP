using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class ProductCommentService
    {
        private readonly ProductCommentRepository _repository;

        public ProductCommentService(ProductCommentRepository repository)
        {
            _repository = repository;
        }

        public async Task<ProductComment> CreateAsync(CreateProductCommentRequest req, int companyId)
        {
            if (string.IsNullOrWhiteSpace(req.Comment))
                throw new InvalidOperationException("Comment cannot be empty.");

            if (await _repository.ExistsAsync(req.Comment, req.ProductId, companyId))
                throw new InvalidOperationException($"Product with Id '{req.ProductId}' Already has this comment '{req.Comment}'.");

            var entity = ProductComment.Create(
                req.ProductId, 
                req.Comment.Trim(), 
                companyId);
            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(UpdateProductCommentRequest req, int companyId)
        {
            var entity = await _repository.GetByIdAsync(req.Id, companyId)
                         ?? throw new InvalidOperationException($"ProductComment with ID '{req.Id}' not found.");

            var finalProductId = req.ProductId ?? entity.ProductId;
            var finalComment = req.Comment ?? entity.Comment;

            if (string.IsNullOrWhiteSpace(finalComment))
                throw new InvalidOperationException("Comment cannot be empty.");

            if ((req.ProductId.HasValue && req.ProductId.Value != entity.ProductId) ||
                (req.Comment != null && req.Comment.ToLower() != entity.Comment.ToLower()))
            {
                if (await _repository.ExistsAsync(finalComment, finalProductId, companyId, req.Id))
                    throw new InvalidOperationException($"Product with Id '{finalProductId}' already has the comment '{finalComment}'.");
            }

            entity.Update(req.ProductId, req.Comment);

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id , int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId)
                         ?? throw new InvalidOperationException($"ProductComment with ID '{id}' not found.");

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
