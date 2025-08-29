//using MediatR;
//using Products.Api.Models;
//using Products.Api.Repository;
//using Products.Api.Helpers;

//namespace Products.Api.Queries.ProductsQuery.Update
//{
//    public class UpdateProductcommand(int id, UpdateProductRequestDto request) : IRequest<UpdateProductRequestDto>
//    {
//        public int Id { get; } = id;
//        public UpdateProductRequestDto Request { get; } = request ?? throw new ArgumentNullException(nameof(request));

//        public class UpdateProductcommandHandler : IRequestHandler<UpdateProductcommand, UpdateProductRequestDto>
//        {
//            private readonly ProductRepository _productRepository;

//            public UpdateProductcommandHandler(ProductRepository productRepository)
//            {
//                _productRepository = productRepository;
//            }

//            public async Task<UpdateProductRequestDto> Handle(UpdateProductcommand request, CancellationToken cancellationToken)
//            {
//                var product = await _productRepository.GetProductByIdAsync(request.Id);
//                if (product == null)
//                    throw new ArgumentException($"Product with ID {request.Id} not found");

//                // Use domain methods to update
//                product.UpdateName(request.Request.Name);
//                product.UpdatePrice(request.Request.Price);
//                //product.UpdateProductGroupName(request.Request.ProductGroupName);
//                // Update other properties
//                product.Code = request.Request.Code;
//                product.Cost = request.Request.Cost;
//                product.Description = request.Request.Description;
//                product.Color = request.Request.Color;
//                product.DateUpdated = DateTime.UtcNow;

//                await _productRepository.UpdateProductAsync(product);
//                return MapperProduct.MapToProduct(product);
//            }
//        }
//    }
//}