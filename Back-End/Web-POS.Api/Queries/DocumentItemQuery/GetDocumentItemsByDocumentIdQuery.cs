using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;
using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.DocumentItemQuery
{
    public class GetDocumentItemsByDocumentIdQuery : IRequest<List<DocumentItemDto>>
    {
        public int DocumentId { get; set; }
        public int CompanyId { get; set; }
        public class GetDocumentItemsByDocumentIdQueryHandler : IRequestHandler<GetDocumentItemsByDocumentIdQuery, List<DocumentItemDto>>
        {
            private readonly DocumentItemRepository _repository;
            private readonly AppDbContext _db;
            public GetDocumentItemsByDocumentIdQueryHandler(DocumentItemRepository repository, AppDbContext db)
            {
                _repository = repository;
                _db = db;
            }
            public async Task<List<DocumentItemDto>> Handle(GetDocumentItemsByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByDocumentIdAsync(request.DocumentId, request.CompanyId);
                var dtos = entities.Select(MapperDocumentItem.MapToDto).ToList();
                if (dtos.Count == 0) return dtos;

                // What each line was sold WITH. The till that rang the sale up
                // reads this from its own Drift copy; this is the path for
                // every other device — and for the same till after a reinstall,
                // which is when a year-old receipt is most likely to be asked
                // for.
                var itemIds = dtos.Select(d => d.Id).ToList();
                var modifiers = await _db.Set<DocumentItemModifier>()
                    .Where(m => itemIds.Contains(m.DocumentItemId) && m.CompanyId == request.CompanyId)
                    .OrderBy(m => m.Rank)
                    .ToListAsync(cancellationToken);

                foreach (var dto in dtos)
                {
                    dto.Modifiers = modifiers
                        .Where(m => m.DocumentItemId == dto.Id)
                        .Select(m => new ModifierSnapshotDto
                        {
                            ModifierOptionId = m.ModifierOptionId,
                            GroupName = m.GroupName,
                            Name = m.Name,
                            AdditionalPrice = m.AdditionalPrice,
                            Rank = m.Rank
                        }).ToList();
                }

                return dtos;
            }
        }
    }
    public class GetDocumentItemsByDocumentIdQueryValidator : AbstractValidator<GetDocumentItemsByDocumentIdQuery>
    {
        public GetDocumentItemsByDocumentIdQueryValidator()
        {
            RuleFor(x => x.DocumentId).GreaterThan(0).WithMessage("Document ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}