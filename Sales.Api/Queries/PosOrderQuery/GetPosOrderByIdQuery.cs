// File: Queries/PosOrderQuery/GetPosOrderByIdQuery.cs

using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;
using System.Threading;
using System.Threading.Tasks;

namespace Sales.Api.Queries.PosOrderQuery
{
    public class GetPosOrderByIdQuery : IRequest<PosOrderDto?>
    {
        public int Id { get; set; }

        // Nested Handler
        public class GetPosOrderByIdQueryHandler : IRequestHandler<GetPosOrderByIdQuery, PosOrderDto?>
        {
            private readonly PosOrderRepository _repository;

            public GetPosOrderByIdQueryHandler(PosOrderRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosOrderDto?> Handle(GetPosOrderByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPosOrder.MapToPosOrderDto(entity);
            }
        }
    }
}