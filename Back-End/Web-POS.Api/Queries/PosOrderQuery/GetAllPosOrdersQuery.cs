using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetAllPosOrdersQuery : IRequest<List<PosOrderDto>>
    {
        public int CompanyId { get; set; }

        // --- VALIDATOR ---
        public class GetAllPosOrdersQueryValidator : AbstractValidator<GetAllPosOrdersQuery>
        {
            public GetAllPosOrdersQueryValidator()
            {
                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be greater than zero.");
            }
        }

        // --- HANDLER ---
        public class GetAllPosOrdersQueryHandler : IRequestHandler<GetAllPosOrdersQuery, List<PosOrderDto>>
        {
            private readonly PosOrderRepository _repository;

            public GetAllPosOrdersQueryHandler(PosOrderRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosOrderDto>> Handle(GetAllPosOrdersQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperPosOrder.MapToPosOrderDto).ToList();
            }
        }
    }
}