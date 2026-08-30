using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;
using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

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
            private readonly AppDbContext _db;

            public GetPosOrderItemsByOrderIdQueryHandler(PosOrderItemRepository repository, AppDbContext db)
            {
                _repository = repository;
                _db = db;
            }

            public async Task<List<PosOrderItemDto>> Handle(GetPosOrderItemsByOrderIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByPosOrderIdAsync(request.PosOrderId, request.CompanyId);
                var dtos = entities.Select(MapperPosOrderItem.MapToPosOrderItemDto).ToList();

                if (!dtos.Any()) return dtos;

                var itemIds = dtos.Select(d => d.Id).ToList();
                var taxes = await _db.PosOrderItemTaxes
                    .Include(t => t.Tax)
                    .Where(t => itemIds.Contains(t.PosOrderItemId) && t.CompanyId == request.CompanyId)
                    .ToListAsync(cancellationToken);

                // The chosen options. One query for the whole order, then
                // grouped in memory — a per-line query here would be N+1 on a
                // list the floor plan reopens constantly.
                var modifiers = await _db.Set<PosOrderItemModifier>()
                    .Where(m => itemIds.Contains(m.PosOrderItemId) && m.CompanyId == request.CompanyId)
                    .OrderBy(m => m.Rank)
                    .ToListAsync(cancellationToken);

                foreach (var dto in dtos)
                {
                    dto.Modifiers = modifiers
                        .Where(m => m.PosOrderItemId == dto.Id)
                        .Select(m => new ModifierSnapshotDto
                        {
                            ModifierOptionId = m.ModifierOptionId,
                            GroupName = m.GroupName,
                            Name = m.Name,
                            AdditionalPrice = m.AdditionalPrice,
                            Rank = m.Rank
                        }).ToList();

                    dto.Taxes = taxes
                        .Where(t => t.PosOrderItemId == dto.Id)
                        .Select(t => new PosOrderItemTaxDto
                        {
                            Id = t.Tax!.Id,
                            Name = t.Tax.Name,
                            Rate = t.Tax.Rate,
                            IsFixed = t.Tax.IsFixed,
                            IsTaxOnTotal = t.Tax.IsTaxOnTotal
                        }).ToList();
                }

                return dtos;
            }
        }
    }
}