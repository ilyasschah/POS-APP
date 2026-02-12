using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PromotionQuery
{
    public class GetPromotionByIdQuery : IRequest<PromotionDto?>
    {
        public int Id { get; set; }

        public class GetPromotionByIdQueryHandler : IRequestHandler<GetPromotionByIdQuery, PromotionDto?>
        {
            private readonly PromotionRepository _repository;

            public GetPromotionByIdQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionDto?> Handle(GetPromotionByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPromotion.MapToPromotionDto(entity);
            }
        }
    }
}