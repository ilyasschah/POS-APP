using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderItemQuery
{
    public class GetPosOrderItemsByOrderIdQuery : IRequest<List<PosOrderItemDto>>
    {
        
        public int PosOrderId { get; set; }
        public int CompanyId { get; set; }


        public class GetPosOrderItemsByOrderIdQueryValidator : AbstractValidator<GetPosOrderItemsByOrderIdQuery>
        {
            public GetPosOrderItemsByOrderIdQueryValidator()
            {
                RuleFor(x => x.PosOrderId)
                    .GreaterThan(0).WithMessage("Order ID must be greater than zero.");
                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be greater than zero.");
            }
        }

        public class GetPosOrderItemsByOrderIdQueryHandler : IRequestHandler<GetPosOrderItemsByOrderIdQuery, List<PosOrderItemDto>>
        {
            private readonly PosOrderItemRepository _repository;

            public GetPosOrderItemsByOrderIdQueryHandler(PosOrderItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosOrderItemDto>> Handle(GetPosOrderItemsByOrderIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByPosOrderIdAsync(request.PosOrderId, request.CompanyId);
                return entities.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList();
            }
        }
    }
}