using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductCommentQuery
{
    public class GetAllProductCommentsQuery : IRequest<List<ProductCommentDto>>
    {
        public class GetAllProductCommentsQueryHandler
            : IRequestHandler<GetAllProductCommentsQuery, List<ProductCommentDto>>
        {
            private readonly ProductCommentRepository _repository;

            public GetAllProductCommentsQueryHandler(ProductCommentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductCommentDto>> Handle(GetAllProductCommentsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperProductComment.MapToProductCommentDto).ToList();
            }
        }
    }
}
