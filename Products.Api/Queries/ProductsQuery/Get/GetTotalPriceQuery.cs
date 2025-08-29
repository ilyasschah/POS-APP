using Products.Api.Repository;

namespace Products.Api.Queries.ProductsQuery.Get
{
    public class GetTotalPriceQuery
    {
        public ProductRepository _productRepository;

        public GetTotalPriceQuery(ProductRepository productRepository)
        {
            _productRepository = productRepository;
        }
        public async Task<decimal> GetTotalPrice(string name)
        {
            var product = await _productRepository.GetTotalPrice(name);
            return product;
        }
    }
}
