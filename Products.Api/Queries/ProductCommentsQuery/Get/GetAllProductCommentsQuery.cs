using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductCommentsQuery.Get
{
    public class GetAllProductCommentsQuery : IRequest<List<ProductCommentDto>>
    {
    }

    public class GetAllProductCommentsQueryHandler : IRequestHandler<GetAllProductCommentsQuery, List<ProductCommentDto>>
    {
        private readonly ProductCommentRepository _productCommentRepository;

        public GetAllProductCommentsQueryHandler(ProductCommentRepository productCommentRepository)
        {
            _productCommentRepository = productCommentRepository;
        }
        public async Task<List<ProductCommentDto>> Handle(GetAllProductCommentsQuery request, CancellationToken cancellationToken)
        {
            var comments = await _productCommentRepository.GetAllProductComments();
            return comments.Select(MapperProductComment.MapToProductComment).ToList();
        }
    }
}