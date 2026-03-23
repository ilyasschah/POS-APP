using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class DocumentItemService
    {
        private readonly DocumentItemRepository _itemRepository;
        private readonly ProductRepository _productRepository;
        private readonly DocumentRepository _documentRepository;

        public DocumentItemService(
            DocumentItemRepository itemRepository,
            ProductRepository productRepository,
            DocumentRepository documentRepository)
        {
            _itemRepository = itemRepository;
            _productRepository = productRepository;
            _documentRepository = documentRepository;
        }

        public async Task<DocumentItemDto> CreateAsync(CreateDocumentItemRequest request, int companyId)
        {
            var product = await _productRepository.GetByIdAsync(request.ProductId, companyId);
            if (product == null) throw new UnauthorizedAccessException("Invalid Product.");

            var document = await _documentRepository.GetByIdAsync(request.DocumentId, companyId);
            if (document == null) throw new UnauthorizedAccessException("Invalid Document.");

            decimal discountBase = request.DiscountType == 1
                ? request.PriceBeforeTax * (request.Discount / 100m)
                : request.Discount;

            decimal discountTaxed = request.DiscountType == 1
                ? request.Price * (request.Discount / 100m)
                : request.Discount;

            decimal pbtd = request.PriceBeforeTax - discountBase;
            decimal pad = request.Price - discountTaxed;
            decimal total = pad * request.Quantity;

            var entity = DocumentItem.Create(
                companyId, request.DocumentId, request.ProductId, request.Quantity, request.ExpectedQuantity,
                request.PriceBeforeTax, request.Price, request.Discount, request.DiscountType,
                request.ProductCost, pbtd, pad, total, total, request.DiscountApplyRule);

            await _itemRepository.AddAsync(entity);
            return MapperDocumentItem.MapToDto(entity);
        }

        public async Task<bool> UpdateAsync(UpdateDocumentItemRequest request, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(request.Id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");

            int targetDocId = request.DocumentId ?? entity.DocumentId;
            if (request.DocumentId.HasValue && request.DocumentId.Value != entity.DocumentId)
            {
                var document = await _documentRepository.GetByIdAsync(targetDocId, companyId);
                if (document == null) throw new UnauthorizedAccessException("Invalid Document.");
            }

            int targetProdId = request.ProductId ?? entity.ProductId;
            if (request.ProductId.HasValue && request.ProductId.Value != entity.ProductId)
            {
                var product = await _productRepository.GetByIdAsync(targetProdId, companyId);
                if (product == null) throw new UnauthorizedAccessException("Invalid Product.");
            }

            decimal calcQuantity = request.Quantity ?? entity.Quantity;
            decimal calcPbt = request.PriceBeforeTax ?? entity.PriceBeforeTax;
            decimal calcPrice = request.Price ?? entity.Price;
            decimal calcDisc = request.Discount ?? entity.Discount;
            int calcDiscType = request.DiscountType ?? entity.DiscountType;

            decimal discountBase = calcDiscType == 1 ? calcPbt * (calcDisc / 100m) : calcDisc;
            decimal discountTaxed = calcDiscType == 1 ? calcPrice * (calcDisc / 100m) : calcDisc;

            decimal pbtd = calcPbt - discountBase;
            decimal pad = calcPrice - discountTaxed;
            decimal total = pad * calcQuantity;

            entity.UpdateDetails(
                targetDocId, targetProdId, calcQuantity,
                request.ExpectedQuantity ?? entity.ExpectedQuantity, calcPbt, calcPrice,
                calcDisc, calcDiscType, request.ProductCost ?? entity.ProductCost,
                pbtd, pad, total, total, request.DiscountApplyRule ?? entity.DiscountApplyRule);

            return await _itemRepository.UpdateAsync(entity);
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var entity = await _itemRepository.GetByIdAsync(id, companyId);
            if (entity == null) throw new KeyNotFoundException("Item not found.");
            return await _itemRepository.DeleteAsync(entity);
        }
    }
}