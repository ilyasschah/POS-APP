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
                var dtos = entities.Select(MapperPosOrder.MapToPosOrderDto).ToList();

                // One grouped query for every order's line stats — deliberately NOT
                // per-order (that would be N+1 on a list the POS polls every 20s).
                // These let a terminal detect that another terminal edited an
                // order's CONTENTS; see the note on PosOrderDto.ItemCount.
                var stats = await _repository.GetItemStatsAsync(
                    dtos.Select(d => d.Id).ToList(), cancellationToken);

                foreach (var dto in dtos)
                {
                    if (!stats.TryGetValue(dto.Id, out var s)) continue;
                    dto.ItemCount = s.Count;
                    dto.ItemsLastChanged = s.LastChanged;
                }

                return dtos;
            }
        }
    }
}