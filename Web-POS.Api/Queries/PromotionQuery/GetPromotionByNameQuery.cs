using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PromotionQuery
{
    public class GetPromotionByNameQuery : IRequest<PromotionDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }

        public class GetPromotionByNameQueryHandler : IRequestHandler<GetPromotionByNameQuery, PromotionDto?>
        {
            private readonly PromotionRepository _repository;

            public GetPromotionByNameQueryHandler(PromotionRepository repository)
            {
                _repository = repository;
            }

            public async Task<PromotionDto?> Handle(GetPromotionByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name, request.CompanyId);
                return entity == null ? null : MapperPromotion.MapToPromotionDto(entity);
            }
        }
    }
}