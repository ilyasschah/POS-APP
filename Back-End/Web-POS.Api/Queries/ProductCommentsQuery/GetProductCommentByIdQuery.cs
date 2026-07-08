using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductCommentsQuery
{
    public class GetProductCommentByIdQuery : IRequest<ProductCommentDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
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
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperProductComment.MapToProductCommentDto(entity);
            }
        }
    }
    public class GetProductCommentByIdQueryValidator : AbstractValidator<GetProductCommentByIdQuery>
    {
        public GetProductCommentByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Product Comment ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
