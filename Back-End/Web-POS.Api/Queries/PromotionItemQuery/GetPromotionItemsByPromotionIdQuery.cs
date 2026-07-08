using MediatR;
using FluentValidation;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.PromotionItemQuery
{
    public class GetPromotionItemsByPromotionIdQuery : IRequest<List<PromotionItemDto>>
    {
        public int PromotionId { get; set; }
        public int CompanyId { get; set; }

        public class GetPromotionItemsByPromotionIdQueryValidator : AbstractValidator<GetPromotionItemsByPromotionIdQuery>
        {
            public GetPromotionItemsByPromotionIdQueryValidator()
            {
                RuleFor(x => x.PromotionId).GreaterThan(0).WithMessage("Promotion ID is required.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID is required.");
            }
        }

        public class GetPromotionItemsByPromotionIdQueryHandler : IRequestHandler<GetPromotionItemsByPromotionIdQuery, List<PromotionItemDto>>
        {
            private readonly PromotionRepository _repository;

            public GetPromotionItemsByPromotionIdQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionItemDto>> Handle(GetPromotionItemsByPromotionIdQuery request, CancellationToken cancellationToken)
            {
                var items = await _repository.GetItemsByPromotionIdAsync(request.PromotionId, request.CompanyId);
                return items.Select(MapperPromotionItem.MapToDto).ToList();
            }
        }
    }
}