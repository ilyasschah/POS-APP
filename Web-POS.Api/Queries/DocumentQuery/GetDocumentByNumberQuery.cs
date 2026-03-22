using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentQuery
{
    public class GetDocumentByNumberQuery : IRequest<DocumentDto?>
    {
        public string Number { get; set; }
        public int CompanyId { get; set; }
        public GetDocumentByNumberQuery(string number)
        {
            Number = number;
        }

        public class GetDocumentByNumberQueryHandler : IRequestHandler<GetDocumentByNumberQuery, DocumentDto?>
        {
            private readonly DocumentRepository _repository;

            public GetDocumentByNumberQueryHandler(DocumentRepository repository)
            {
                _repository = repository;
            }

            public async Task<DocumentDto?> Handle(GetDocumentByNumberQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNumberAsync(request.Number, request.CompanyId);
                return entity == null ? null : MapperDocument.MapToDocumentDto(entity);
            }
        }
    }
}