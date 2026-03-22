// File: Queries/PosOrderQuery/GetPosOrderByNumberQuery.cs

using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetPosOrderByNumberQuery : IRequest<PosOrderDto?>
    {
        public string Number { get; }
        public int CompanyId { get; set; }

        public GetPosOrderByNumberQuery(string number)
        {
            Number = number;
        }

        // Nested Handler
        public class GetPosOrderByNumberQueryHandler : IRequestHandler<GetPosOrderByNumberQuery, PosOrderDto?>
        {
            private readonly PosOrderRepository _repository;

            public GetPosOrderByNumberQueryHandler(PosOrderRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosOrderDto?> Handle(GetPosOrderByNumberQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNumberAsync(request.Number);
                return entity == null ? null : MapperPosOrder.MapToPosOrderDto(entity);
            }
        }
    }
}