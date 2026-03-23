using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;
using FluentValidation;

namespace Api.Queries.DocumentItemQuery
{
    public class GetAllDocumentItemQuery : IRequest<List<DocumentItemDto>>
    {
        public int CompanyId { get; set; }
        public class GetAllDocumentItemQueryHandler : IRequestHandler<GetAllDocumentItemQuery, List<DocumentItemDto>>
        {
            private readonly DocumentItemRepository _documentItemRepository;
            public GetAllDocumentItemQueryHandler(DocumentItemRepository documentItemRepository)
            {
                _documentItemRepository = documentItemRepository;
            }
            public async Task<List<DocumentItemDto>> Handle(GetAllDocumentItemQuery request, CancellationToken cancellationToken)
            {
                var documentitem = await _documentItemRepository.GetAllAsync(request.CompanyId);
                return documentitem.Select(MapperDocumentItem.MapToDto).ToList();
            }
        }
    }
    public class GetAllDocumentItemQueryValidator : AbstractValidator<GetAllDocumentItemQuery>
    {
        public GetAllDocumentItemQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
