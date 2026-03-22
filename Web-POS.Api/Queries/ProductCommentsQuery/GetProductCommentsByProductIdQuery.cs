using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductCommentsQuery
{
    public class GetProductCommentsByProductIdQuery : IRequest<List<ProductCommentDto>>
    {
        public int ProductId { get; set; }

        public class GetProductCommentsByProductIdQueryHandler
            : IRequestHandler<GetProductCommentsByProductIdQuery, List<ProductCommentDto>>
        {
            private readonly ProductCommentRepository _repository;

            public GetProductCommentsByProductIdQueryHandler(ProductCommentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductCommentDto>> Handle(GetProductCommentsByProductIdQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetByProductIdAsync(request.ProductId);
                return list.Select(MapperProductComment.MapToProductCommentDto).ToList();
            }
        }
    }
}
