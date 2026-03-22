using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductCommentsQuery
{
    public class GetProductCommentByIdQuery : IRequest<ProductCommentDto?>
    {
        public int Id { get; set; }

        public class GetProductCommentByIdQueryHandler
            : IRequestHandler<GetProductCommentByIdQuery, ProductCommentDto?>
        {
            private readonly ProductCommentRepository _repository;

            public GetProductCommentByIdQueryHandler(ProductCommentRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductCommentDto?> Handle(GetProductCommentByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperProductComment.MapToProductCommentDto(entity);
            }
        }
    }
}
