using MediatR;
using FluentValidation;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentQuery
{
    public class GetDocumentByIdQuery : IRequest<DocumentDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetDocumentByIdQueryHandler : IRequestHandler<GetDocumentByIdQuery, DocumentDto?>
        {
            private readonly DocumentRepository _repository;

            public GetDocumentByIdQueryHandler(DocumentRepository repository)
            {
                _repository = repository;
            }

            public async Task<DocumentDto?> Handle(GetDocumentByIdQuery request, CancellationToken cancellationToken)
            {
                var document = await _repository.GetByIdAsync(request.Id, request.CompanyId);

                return document == null ? null : MapperDocument.MapToDocumentDto(document);
            }
        }
    }

    public class GetDocumentByIdQueryValidator : AbstractValidator<GetDocumentByIdQuery>
    {
        public GetDocumentByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Document ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}