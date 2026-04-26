using MediatR;
using Api.Models;
using Api.Repository;

namespace Api.Queries.PromotionQuery
{
    public class GetAllPromotionsQuery : IRequest<List<PromotionDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPromotionsQueryHandler : IRequestHandler<GetAllPromotionsQuery, List<PromotionDto>>
        {
            private readonly PromotionRepository _repository;

            public GetAllPromotionsQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PromotionDto>> Handle(GetAllPromotionsQuery request, CancellationToken cancellationToken)
            {
                var promotions = await _repository.GetAllAsync(request.CompanyId);

                return promotions.Select(p => new PromotionDto
                {
                    Id = p.Id,
                    CompanyId = p.CompanyId,
                    Name = p.Name,
                    DaysOfWeek = p.DaysOfWeek,
                    StartDate = p.StartDate,
                    EndDate = p.EndDate,
                    StartTime = p.StartTime,
                    EndTime = p.EndTime,
                    IsEnabled = p.IsEnabled,

                    Items = p.Items.Select(i => new PromotionItemDto
                    {
                        Id = i.Id,
                        PromotionId = i.PromotionId,
                        ProductId = i.Uid,
                        DiscountType = i.DiscountType,
                        PriceType = i.PriceType,
                        Value = i.Value,
                        IsConditional = i.IsConditional,
                        Quantity = i.Quantity,
                        ConditionType = i.ConditionType,
                        QuantityLimit = i.QuantityLimit
                    }).ToList()
                }).ToList();
            }
        }
    }
}