using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.ProductCommentsQuery
{
    public class GetAllProductCommentsQuery : IRequest<List<ProductCommentDto>>
    {
        public int CompanyId { get; set; }
        public class GetAllProductCommentsQueryHandler : IRequestHandler<GetAllProductCommentsQuery, List<ProductCommentDto>>
        {
            private readonly ProductCommentRepository _repository;

            public GetAllProductCommentsQueryHandler(ProductCommentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductCommentDto>> Handle(GetAllProductCommentsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperProductComment.MapToProductCommentDto).ToList();
            }
        }
    }
    public class GetAllProductCommentsQueryValidator : AbstractValidator<GetAllProductCommentsQuery>
    {
        public GetAllProductCommentsQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
