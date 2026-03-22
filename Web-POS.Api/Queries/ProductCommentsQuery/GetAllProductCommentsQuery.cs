using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductCommentsQuery
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
