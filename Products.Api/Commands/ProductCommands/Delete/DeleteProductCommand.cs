//using MediatR;
//using Products.Api.Repository;

//namespace Products.Api.Commands.ProductCommands.Delete
//{
//    public class DeleteProductcommand(int id) : IRequest<bool>
//    {
//        public int Id { get; } = id;

//        public class DeleteProductcommandHandler : IRequestHandler<DeleteProductcommand, bool>
//        {
//            private readonly ProductRepository _productRepository;

//            public DeleteProductcommandHandler(ProductRepository productRepository)
//            {
//                _productRepository = productRepository;
//            }

//            public Task<bool> Handle(DeleteProductcommand request, CancellationToken cancellationToken)
//            {
//                return true;
//            }
//        }
//    }
//}