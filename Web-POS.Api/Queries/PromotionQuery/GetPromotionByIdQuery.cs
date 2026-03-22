using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PromotionQuery
{
    public class GetPromotionByIdQuery : IRequest<PromotionDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetPromotionByIdQueryHandler : IRequestHandler<GetPromotionByIdQuery, PromotionDto?>
        {
            private readonly PromotionRepository _repository;

            public GetPromotionByIdQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionDto?> Handle(GetPromotionByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperPromotion.MapToPromotionDto(entity);
            }
        }
    }
}