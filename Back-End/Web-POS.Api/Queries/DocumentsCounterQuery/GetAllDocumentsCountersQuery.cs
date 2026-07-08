using MediatR;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.DocumentsCounterQuery
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