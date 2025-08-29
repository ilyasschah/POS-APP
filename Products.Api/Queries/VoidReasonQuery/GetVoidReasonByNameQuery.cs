using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Queries.VoidReasonQuery
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