using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.DocumentItemQuery
{
    public class GetDocumentItemsByDocumentIdQuery : IRequest<List<DocumentItemDto>>
    {
        public int DocumentId { get; set; }
        public int CompanyId { get; set; }
        public class GetDocumentItemsByDocumentIdQueryHandler : IRequestHandler<GetDocumentItemsByDocumentIdQuery, List<DocumentItemDto>>
        {
            private readonly DocumentItemRepository _repository;
            public GetDocumentItemsByDocumentIdQueryHandler(DocumentItemRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<DocumentItemDto>> Handle(GetDocumentItemsByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByDocumentIdAsync(request.DocumentId, request.CompanyId);
                return entities.Select(MapperDocumentItem.MapToDto).ToList();
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