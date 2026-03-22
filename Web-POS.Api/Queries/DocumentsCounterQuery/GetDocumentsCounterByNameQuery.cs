using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentsCounterQuery
{
    public class GetDocumentsCounterByNameQuery : IRequest<DocumentsCounterDto?>
    {
        public string Name { get; set; }

        public class GetDocumentsCounterByNameQueryHandler : IRequestHandler<GetDocumentsCounterByNameQuery, DocumentsCounterDto?>
        {
            private readonly DocumentsCounterRepository _repository;

            public GetDocumentsCounterByNameQueryHandler(DocumentsCounterRepository repository)
            {
                _repository = repository;
            }

            public async Task<DocumentsCounterDto?> Handle(GetDocumentsCounterByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperDocumentsCounter.MapToDocumentsCounterDto(entity);
            }
        }
    }
}