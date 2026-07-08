using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductsQuery
{
    public class GetProductByIdQuery : IRequest<ProductDto?>
    {
        public int Id { get; set; }

        public class GetProductByIdQueryHandler : IRequestHandler<GetProductByIdQuery, ProductDto?>
        {
            private readonly ProductRepository _repository;

            public GetProductByIdQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductDto?> Handle(GetProductByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperProduct.MapToProductDto(entity);
            }
        }
    }
}
