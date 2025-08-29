//using Products.Api.Models;
//using Products.Api.Helpers;
//using Products.Api.Repository;

//namespace Products.Api.Queries.ProductsQuery.Get
//{
//    public class SearchByNameQuery
//    {
//        public ProductRepository _productRepository;

//        public SearchByNameQuery(ProductRepository productRepository)
//        {
//            _productRepository = productRepository;
//        }
//        public async Task<ProductInfoRequestDto> GetByName(string name)
//        {
//            var product = await _productRepository.GetProductByNameforBarecodeAsync(name);
//            if (product == null) return null;
//            return MapperProduct.MapToProduct(product);
//        }
//    }
//}
