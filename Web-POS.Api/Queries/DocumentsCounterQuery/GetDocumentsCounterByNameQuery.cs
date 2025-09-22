using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentsCounterQuery
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