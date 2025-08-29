//using Products.Api.Helpers;
//using Products.Api.Models;
//using Products.Api.Repository;

//namespace Products.Api.Queries.ProductsQuery.Get
//{
//    public class GetProductByIdQuery 
//    {
//        public ProductRepository _productRepository;
    
//        public GetProductByIdQuery(ProductRepository productRepository)
//        {
//            _productRepository = productRepository;
//        }
//        public async Task<ProductInfoRequestDto> GetById(int id)
//        {
//            var product = await _productRepository.GetProductByIdAsync(id);
//           if (product == null)
//           throw new KeyNotFoundException($"Product with ID {id} not found.");
//           return MapperProduct.MapToProductDetail(product);
//        }
//    }
//}
