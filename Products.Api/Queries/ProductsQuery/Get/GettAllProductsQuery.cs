using MediatR;
using Products.Api.Domain;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
namespace Products.Api.Queries.ProductsQuery.Get
{
    public class GettAllProductsQuery : IRequest<List<ProductDto>>
    {
        public class GettAllProductsQueryHandler : IRequestHandler<GettAllProductsQuery, List<ProductDto>>
        {
            private readonly ProductRepository _productRepository;
            public GettAllProductsQueryHandler(ProductRepository productRepository)
            {
                _productRepository = productRepository;
            }
            public async Task<List<ProductDto>> Handle(GettAllProductsQuery request, CancellationToken cancellationToken)
            {
                var products = await _productRepository.GetProducts();
                return products.Select(MapperProduct.MapToProductDetail).ToList();
            }
        }
    }
}