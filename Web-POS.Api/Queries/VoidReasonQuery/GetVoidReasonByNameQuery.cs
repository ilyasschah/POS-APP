using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.VoidReasonQuery
{
    public class GetVoidReasonByNameQuery : IRequest<VoidReasonDto?>
    {
        public string Name { get; set; }

        public class GetVoidReasonByNameQueryHandler : IRequestHandler<GetVoidReasonByNameQuery, VoidReasonDto?>
        {
            private readonly VoidReasonRepository _repository;

            public GetVoidReasonByNameQueryHandler(VoidReasonRepository repository)
            {
                _repository = repository;
            }

            public async Task<VoidReasonDto?> Handle(GetVoidReasonByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperVoidReason.MapToVoidReasonDto(entity);
            }
        }
    }
}