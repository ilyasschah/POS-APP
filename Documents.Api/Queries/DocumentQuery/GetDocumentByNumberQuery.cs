using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentQuery
{
    public class GetDocumentByNumberQuery : IRequest<DocumentDto?>
    {
        public string Number { get; set; }
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
                var entity = await _repository.GetByNumberAsync(request.Number);
                return entity == null ? null : MapperDocument.MapToDocumentDto(entity);
            }
        }
    }
}