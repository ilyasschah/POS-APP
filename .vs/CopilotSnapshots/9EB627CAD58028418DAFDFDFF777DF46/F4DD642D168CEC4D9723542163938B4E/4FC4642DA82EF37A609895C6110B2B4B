using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductsQuery
{
    public class GetAllProductsQuery : IRequest<List<ProductDto>>
    {
        public class GetAllProductsQueryHandler : IRequestHandler<GetAllProductsQuery, List<ProductDto>>
        {
            private readonly ProductRepository _repository;

            public GetAllProductsQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductDto>> Handle(GetAllProductsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperProduct.MapToProductDto).ToList();
            }
        }
    }
}
