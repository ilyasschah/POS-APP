using MediatR;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Products.Api.Repository;
using Products.Api.Helpers;
using Products.Api.Models;

namespace Products.Api.Queries.DocumentsCounterQuery
{
    public class GetAllDocumentsCountersQuery : IRequest<List<DocumentsCounterDto>>
    {
        public class GetAllDocumentsCountersQueryHandler : IRequestHandler<GetAllDocumentsCountersQuery, List<DocumentsCounterDto>>
        {
            private readonly DocumentsCounterRepository _repository;

            public GetAllDocumentsCountersQueryHandler(DocumentsCounterRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<DocumentsCounterDto>> Handle(GetAllDocumentsCountersQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperDocumentsCounter.MapToDocumentsCounterDto).ToList();
            }
        }
    }
}