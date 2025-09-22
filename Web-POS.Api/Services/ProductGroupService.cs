using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class ProductGroupService
    {
        private readonly ProductGroupRepository _repository;

        public ProductGroupService(ProductGroupRepository repository)
        {
            _repository = repository;
        }

        private static byte[]? DecodeBase64(string? b64)
        {
            if (string.IsNullOrWhiteSpace(b64)) return null;
            try { return Convert.FromBase64String(b64); }
            catch { return null; }
        }

        public async Task<ProductGroup> Create(CreateProductGroupRequest req)
        {
            if (await _repository.ExistsByNameAsync(req.Name))
                throw new InvalidOperationException($"ProductGroup with name '{req.Name}' already exists.");

            if (req.ParentGroupId.HasValue)
            {
                var parent = await _repository.GetByIdAsync(req.ParentGroupId.Value);
                if (parent is null)
                    throw new InvalidOperationException($"Parent ProductGroup with Id '{req.ParentGroupId}' not found.");
            }

            var entity = ProductGroup.Create(
                name: req.Name,
                parentGroupId: req.ParentGroupId,
                color: string.IsNullOrWhiteSpace(req.Color) ? "Transparent" : req.Color!,
                image: DecodeBase64(req.ImageBase64),
                rank: req.Rank ?? 0
            );

            await _repository.AddAsync(entity);
            return entity;
        }

        public async Task<bool> Update(int id, UpdateProductGroupRequest req)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true)
                         ?? throw new InvalidOperationException($"ProductGroup with ID '{id}' not found.");

            if (await _repository.ExistsByNameAsync(req.Name))
            {
                var byName = await _repository.GetByNameAsync(req.Name);
                if (byName != null && byName.Id != id)
                    throw new InvalidOperationException($"Another ProductGroup with name '{req.Name}' already exists.");
            }

            if (req.ParentGroupId.HasValue)
            {
                if (req.ParentGroupId.Value == id)
                    throw new InvalidOperationException("A ProductGroup cannot be its own parent.");

                var parent = await _repository.GetByIdAsync(req.ParentGroupId.Value);
                if (parent is null)
                    throw new InvalidOperationException($"Parent ProductGroup with Id '{req.ParentGroupId}' not found.");
            }

            var imageBytes = DecodeBase64(req.ImageBase64) ?? entity.Image;

            entity.Update(
                name: req.Name,
                parentGroupId: req.ParentGroupId,
                color: string.IsNullOrWhiteSpace(req.Color) ? "Transparent" : req.Color,
                image: imageBytes,
                rank: req.Rank
            );

            await _repository.UpdateAsync(entity);
            return true;
        }

        public async Task<bool> Delete(int id)
        {
            var entity = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entity == null) return false;

            // Optional: guard against deleting groups that still have children.
            // If you prefer automatic cascade via FK, remove this check.
            var children = await _repository.GetChildrenAsync(id);
            if (children.Count > 0)
                throw new InvalidOperationException("Cannot delete a ProductGroup that has child groups. Move or delete its children first.");

            await _repository.DeleteAsync(entity);
            return true;
        }
    }
}
