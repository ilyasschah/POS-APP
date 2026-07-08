using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductsQuery
{
    public class GetProductByCodeQuery : IRequest<ProductDto?>
    {
        public string Code { get; set; } = default!;

        public class GetProductByCodeQueryHandler : IRequestHandler<GetProductByCodeQuery, ProductDto?>
        {
            private readonly ProductRepository _repository;

            public GetProductByCodeQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductDto?> Handle(GetProductByCodeQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByCodeAsync(request.Code);
                return entity == null ? null : MapperProduct.MapToProductDto(entity);
            }
        }
    }
}
