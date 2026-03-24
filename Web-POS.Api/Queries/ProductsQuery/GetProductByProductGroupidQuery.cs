using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.ProductsQuery
{
    public class GetProductByProductGroupQuery : IRequest<ProductDto?>
    {
        public int ProductGroup { get; set; } = default!;
        public int CompanyId { get; set; }

        public class GetProductByProductGroupQueryHandler : IRequestHandler<GetProductByProductGroupQuery, ProductDto?>
        {
            private readonly ProductRepository _repository;

            public GetProductByProductGroupQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductDto?> Handle(GetProductByProductGroupQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByProductGroupAsync(request.ProductGroup, request.CompanyId);
                return entity == null ? null : MapperProduct.MapToProductDtoPG(entity);
            }
        }
    }
}
