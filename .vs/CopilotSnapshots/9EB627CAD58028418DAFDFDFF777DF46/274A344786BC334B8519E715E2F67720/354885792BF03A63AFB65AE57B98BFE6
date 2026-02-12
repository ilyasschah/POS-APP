using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PromotionQuery
{
    public class GetPromotionByNameQuery : IRequest<PromotionDto?>
    {
        public string Name { get; set; }

        public class GetPromotionByNameQueryHandler : IRequestHandler<GetPromotionByNameQuery, PromotionDto?>
        {
            private readonly PromotionRepository _repository;

            public GetPromotionByNameQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionDto?> Handle(GetPromotionByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperPromotion.MapToPromotionDto(entity);
            }
        }
    }
}