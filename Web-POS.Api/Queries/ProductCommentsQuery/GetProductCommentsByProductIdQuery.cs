using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductCommentsQuery
{
    public class GetProductCommentsByProductIdQuery : IRequest<List<ProductCommentDto>>
    {
        public int ProductId { get; set; }
        public int CompanyId { get; set; }
        public class GetProductCommentsByProductIdQueryHandler : IRequestHandler<GetProductCommentsByProductIdQuery, List<ProductCommentDto>>
        {
            private readonly ProductCommentRepository _repository;

            public GetProductCommentsByProductIdQueryHandler(ProductCommentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductCommentDto>> Handle(GetProductCommentsByProductIdQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetByProductIdAsync(request.ProductId, request.CompanyId);
                return list.Select(MapperProductComment.MapToProductCommentDto).ToList();
            }
        }
    }
    public class GetProductCommentsByProductIdQueryValidator : AbstractValidator<GetProductCommentsByProductIdQuery>
    {
        public GetProductCommentsByProductIdQueryValidator()
        {
            RuleFor(x => x.ProductId).GreaterThan(0).WithMessage("Product ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
