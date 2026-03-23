using MediatR;
using Api.Repository;
using Api.Models;
using Api.Helpers;
using FluentValidation;

namespace Api.Queries.DocumentItemQuery
{
    public class GetDocumentItemsByIdQuery : IRequest<DocumentItemDto>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
    }
    public class GetDocumentItemsByIdQueryHandler : IRequestHandler<GetDocumentItemsByIdQuery, DocumentItemDto>
    {
        private readonly DocumentItemRepository _documentItemRepository;
        public GetDocumentItemsByIdQueryHandler(DocumentItemRepository documentItemRepository)
        {
            _documentItemRepository = documentItemRepository;
        }
        public async Task<DocumentItemDto?> Handle(GetDocumentItemsByIdQuery request, CancellationToken cancellationToken)
        {
            var documentitem = await _documentItemRepository.GetByIdAsync(request.Id, request.CompanyId);
            return documentitem == null ? null : MapperDocumentItem.MapToDto(documentitem);
        }
    }
    public class GetDocumentItemsByIdQueryValidator : AbstractValidator<GetDocumentItemsByIdQuery>
    {
        public GetDocumentItemsByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Document Item ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}


