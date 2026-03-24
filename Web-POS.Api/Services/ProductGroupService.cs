using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class ProductGroupService
    {
        private readonly ProductGroupRepository _repository;

        public ProductGroupService(ProductGroupRepository repository)
        {
            _repository = repository;
        }

        public async Task<ProductGroupDto> CreateAsync(CreateProductGroupRequest request, int companyId)
        {
            if (!await _repository.IsNameUniqueAsync(request.Name, companyId))
                throw new InvalidOperationException($"A product group named '{request.Name}' already exists.");

            if (request.ParentGroupId.HasValue)
            {
                var parent = await _repository.GetByIdAsync(request.ParentGroupId.Value, companyId);
                if (parent == null) throw new UnauthorizedAccessException("Invalid Parent Group.");
            }

            var entity = ProductGroup.Create(
                request.Name, request.ParentGroupId, request.Color ?? "Transparent",
                request.Image, request.Rank, companyId);

            await _repository.AddAsync(entity);

            var savedEntity = await _repository.GetByIdAsync(entity.Id, companyId);
            return MapperProductGroup.MapToDto(savedEntity!);
        }

        public async Task<bool> UpdateAsync(UpdateProductGroupRequest request, int companyId)
        {
            var entity = await _repository.GetByIdAsync(request.Id, companyId);
            if (entity == null) throw new KeyNotFoundException("Product Group not found.");

            if (request.Name != null && request.Name != entity.Name)
            {
                if (!await _repository.IsNameUniqueAsync(request.Name, companyId, request.Id))
                    throw new InvalidOperationException($"A product group named '{request.Name}' already exists.");
            }

            int? targetParentId = request.ParentGroupId ?? entity.ParentGroupId;
            if (request.ParentGroupId.HasValue && request.ParentGroupId.Value != entity.ParentGroupId)
            {
                if (request.ParentGroupId.Value == request.Id)
                    throw new InvalidOperationException("A group cannot be its own parent.");

                var parent = await _repository.GetByIdAsync(request.ParentGroupId.Value, companyId);
                if (parent == null) throw new UnauthorizedAccessException("Invalid Parent Group.");
            }

            entity.Update(
                request.Name ?? entity.Name,
                targetParentId,
                request.Color ?? entity.Color,
                request.Image ?? entity.Image,
                request.Rank ?? entity.Rank,
                companyId);

            return await _repository.UpdateAsync(entity);
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _repository.GetByIdAsync(id, companyId);
            if (entity == null) throw new KeyNotFoundException("Product Group not found.");
            return await _repository.DeleteAsync(entity);
        }
    }
}