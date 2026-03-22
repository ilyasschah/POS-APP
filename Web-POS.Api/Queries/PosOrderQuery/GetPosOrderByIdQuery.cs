// File: Queries/PosOrderQuery/GetPosOrderByIdQuery.cs

using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetPosOrderByIdQuery : IRequest<PosOrderDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

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
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperPosOrder.MapToPosOrderDto(entity);
            }
        }
    }
}